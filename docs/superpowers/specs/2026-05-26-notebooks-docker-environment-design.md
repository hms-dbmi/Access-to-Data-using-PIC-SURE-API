# Docker environment for the PIC-SURE example notebooks

**Date:** 2026-05-26
**Status:** Draft (awaiting user review)
**Repo:** `Access-to-Data-using-PIC-SURE-API/` (branch `adapters_v3`)

## Problem

The example notebooks have no reproducible runtime. Running them today means
hand-installing a Python scientific stack, a large R/CRAN + Bioconductor stack,
both PIC-SURE adapters, and wiring up Jupyter and/or RStudio. We want a single
`docker-compose.yml` in this repo that stands up an environment capable of
running every **v3-adapter** notebook, with the adapters installed from git and
the notebook files themselves editable in place.

## Scope

### In scope — the v3-adapter notebooks

These target the rewritten `picsure` adapters and must run in the environment:

- `NHLBI_BioData_Catalyst/python/` — the 9 ported notebooks: `0_Export_from_UI`,
  `1_PICSURE_API_101`, `2_TOPMed_DCC_Harmonized_Variables_analysis`, `3_PheWAS`,
  `5_LongitudinalData`, `6_Sickle_Cell`, `7_Harmonization_with_PICSURE`,
  `8_RECOVER`, `ORCHID_COVID19_python`. Plus `Workspace_setup`.
- `NHLBI_BioData_Catalyst/R/` — all R notebooks (use the R `picsure` adapter).
- `NHLBI_BioData_Catalyst/Rstudio/` — the `.Rmd` equivalents (RStudio service).
- `AIM-AHEAD/NHANES_PICSURE_R.ipynb`.
- `NIH_Undiagnosed_Diseases_Network/R/PICSURE_API_101.ipynb`.

### Out of scope — legacy v2 notebooks

These import the old `PicSureClient` / `PicSureBdcAdapter` /
`pic-sure-biodatacatalyst` packages (not the two adapters in this workspace) and
self-install them from git at runtime: `AIM-AHEAD/NHANES_PICSURE_python`, both
`NCATS_Genomic_Information_Commons/Python/*`, both
`NIH_Undiagnosed_Diseases_Network/Python/*`, and
`NHLBI_BioData_Catalyst/python/4_Genomic_Queries` (no genomic filter in v3).

They will still **open** in the environment, and the `dev` shell has git +
network if someone wants to run their install cells manually, but they are not a
supported target and their dependencies are not pre-provisioned.

### Also out of scope

- PIC-SURE auth tokens. Notebooks supply a token at runtime (in-notebook or via
  `.env`), same as today. The image provisions no credentials.
- Modifying any notebook, adapter, or other repo content.

## Decisions (from brainstorming)

| Decision | Choice |
| --- | --- |
| Notebooks supported | v3-adapter notebooks only |
| Adapter install | From **git** (GitHub `hms-dbmi`), **not** editable, not local source |
| Adapter git ref | Configurable build args, **default `main`** |
| Repo files | Editable — bind-mounted read-write at `/workspace` |
| Services | `dev` (bash), `notebook` (JupyterLab :8888), `rstudio` (RStudio :8787) |

## Architecture

Mirror the **R adapter's** Docker setup (`pic-sure-r-adapter-hpds/docker/`) —
it is the only existing image that already combines R + RStudio + Python +
JupyterLab + IRkernel, which is exactly what a mixed Python/R notebook repo
needs. New files, all inside this repo:

```
docker/Dockerfile         # the combined image
docker/entrypoint.sh      # first-run adapter install, RStudio override aware
docker-compose.yml        # dev / notebook / rstudio
.env.example              # UID/GID, adapter refs, optional PICSURE token vars
docs/development-docker.md # how to use it
```

### Image (`docker/Dockerfile`)

- `FROM rocker/rstudio:4.4` — R 4.4, RStudio Server, pandoc, Ubuntu noble.
- System build deps for R packages (the same apt set as the R adapter
  Dockerfile: libcurl/ssl/xml2/fontconfig/harfbuzz/png/tiff/jpeg/icu/zmq …),
  plus `git`, `tini`, `python3`/`venv`/`pip`.
- Pinned `uv` copied from `ghcr.io/astral-sh/uv` (no curl-pipe-sh).
- JupyterLab + `ipykernel` (Python kernel) installed via pip.
- `pak`, `IRkernel`, `IRkernel::installspec(user = FALSE)` (R kernel registered
  system-wide), `languageserver`.
- **Heavy R notebook stack installed at build time** via `pak` from Posit
  Package Manager binaries: `tidyverse` (dplyr, tidyr, stringr, forcats,
  ggplot2, tibble), `survival`, `survminer`, `cmprsk`, `quantreg`, `DescTools`,
  `arsenal`, `coin`, `kableExtra`, `ggtext`, `ggrepel`; plus `BiocManager` →
  `limma` (Bioconductor). Baked into the image (not the entrypoint) so it is
  shared by all containers and cached in the image layer.
- **Python notebook stack installed at build time** into `/opt/venv`:
  `pandas numpy matplotlib seaborn matplotlib-venn statsmodels scipy`.
- Build args `PY_ADAPTER_REF` / `R_ADAPTER_REF` (default `main`) and `USER_UID`
  / `USER_GID`.
- `RETICULATE_PYTHON=/opt/venv/bin/python` and managed-venv disabled — see
  "Adapter installation" below.

The notebook scientific stacks and R packages are baked into the image because
they are large and stable; only the **adapters** are (re)installed at entrypoint
time so a ref change does not force a full image rebuild.

### Adapter installation

Both adapters come from git, ref configurable, default `main`.

- **Python adapter** → installed into the shared `/opt/venv`:
  `pip install "picsure @ git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@${PY_ADAPTER_REF}"`.
  This venv backs the JupyterLab Python kernel.
- **R adapter** → installed via `pak`:
  `pak::pkg_install("github::hms-dbmi/pic-sure-r-adapter-hpds@${R_ADAPTER_REF}")`.

**Reticulate / Python-for-R integration.** The R adapter's `zzz.R` hard-codes
its Python dependency to `picsure @ git+...@main` via `reticulate::py_require`
under a managed venv. To (a) make `PY_ADAPTER_REF` authoritative for *both*
kernels and (b) avoid a second, divergent Python install, the image sets
`RETICULATE_PYTHON=/opt/venv/bin/python` so reticulate uses the same
`/opt/venv` where the Python adapter was already installed at the configured
ref. `py_require`'s managed-venv resolution is bypassed because an explicit
interpreter is pinned. Net effect: one Python adapter install, one ref, shared
by the Python kernel and R/reticulate.

This `RETICULATE_PYTHON` override is the single deliberate deviation from the R
adapter's stock Docker behavior, and it is what lets the R ref and Python ref be
controlled independently.

### Install timing — build vs. entrypoint

- **Build time:** system libs, uv, JupyterLab, R kernel + R notebook packages +
  Bioconductor, Python notebook packages. Slow, but cached in image layers.
- **Entrypoint, first run, stamped:** install both adapters at the configured
  refs into `/opt/venv` and `/opt/R/library`. Stamp files on the named volumes
  skip reinstall on subsequent `--rm` runs. Bumping a ref → `docker compose
  build --build-arg` (re-bakes nothing heavy) or delete the stamp to force
  reinstall.

The `rstudio` service overrides ENTRYPOINT to rocker's `/init` (s6), so the
adapter-install entrypoint does not gate RStudio startup — adapters are
installed by the first `dev`/`notebook` run sharing the same volumes, or
manually from an RStudio terminal. This matches the R adapter's compose comment.

### `docker-compose.yml`

`x-common` YAML anchor (matching both adapter compose files) carrying the shared
image, build block with the four build args, `.env` (optional), the
`/workspace` bind-mount, and named volumes. Three services:

| Service | Port | Command |
| --- | --- | --- |
| `dev` | — | `bash` (interactive) |
| `notebook` | `127.0.0.1:8888` | `jupyter lab` (no token, `--root_dir=/workspace`) |
| `rstudio` | `127.0.0.1:8787` | rocker `/init`, `DISABLE_AUTH=true` |

Named volumes: `picsure-venv` (`/opt/venv`), `picsure-r-library`
(`/opt/R/library`), `uv-cache`. Bind-mount: `.:/workspace` (the editable repo).
**No adapter bind-mounts** — adapters live in the image / volumes, from git.

## Data / control flow

1. `docker compose build` → image with all heavy notebook deps baked in.
2. `docker compose up notebook` (or `rstudio`) → entrypoint installs the two
   adapters from git at the configured refs into the shared volumes (first run
   only), then launches the server.
3. User opens JupyterLab :8888 / RStudio :8787, edits and runs notebooks under
   `/workspace`; edits persist to the host repo. Adapter ref bumps via build
   arg + stamp reset.

## Error handling / edge cases

- **First build is long** (~10–20 min: tidyverse + survminer + Bioconductor
  `limma`). One-time; documented in `docs/development-docker.md`.
- **No token** → notebooks fail at connect with the adapter's normal auth error;
  documented, not the image's concern.
- **Git ref doesn't have the v3 API** → adapter install/import fails fast at
  entrypoint with a clear pip/pak error; default `main` is the known-good ref.
- **Legacy v2 notebook run** → its own pip cell installs old packages from git
  in the running container (network available); not pre-provisioned, may not
  reflect the v3 adapters.

## Testing / verification

No automated tests for infra. Manual acceptance:

1. `docker compose build` succeeds.
2. `docker compose up notebook` → JupyterLab reachable at :8888 with both a
   Python 3 and an R kernel listed.
3. In a Python kernel: `import picsure` succeeds.
4. In an R kernel: `library(picsure)` succeeds and `reticulate::py_config()`
   reports `/opt/venv/bin/python`.
5. `docker compose up rstudio` → RStudio at :8787 (no auth), opens in
   `/workspace`, an `.Rmd` under `Rstudio/` knits its setup cells.
6. Connect-and-query is left to integration with a real token (out of scope).

## Open assumptions

- "Installed using git" + "default main" means the GitHub `hms-dbmi` remotes at
  `main`. The local working branches (`fix/code-review-findings`, `query_v3`)
  are reachable by overriding the build args if `main` lacks the needed v3 work.
