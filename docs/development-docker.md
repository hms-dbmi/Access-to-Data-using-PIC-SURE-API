# Running the notebooks with Docker

A single `docker-compose.yml` provides a reproducible environment for the
**v3-adapter** notebooks — all R notebooks and the 9 ported
`NHLBI_BioData_Catalyst/python/` notebooks. Both PIC-SURE adapters are
installed from git; the repo is bind-mounted so your edits are live.

> Legacy v2 notebooks (`AIM-AHEAD/NHANES_PICSURE_python`, the
> `NCATS_*/Python` and `NIH_*/Python` notebooks, and
> `NHLBI_BioData_Catalyst/python/4_Genomic_Queries`) are not pre-provisioned.
> They will open, and the `dev` shell has network + git if you want to run
> their own install cells, but they target the old client, not the v3 adapters.

## Prerequisites

- Docker Desktop (or Docker Engine + the `docker compose` plugin).

## Build

```bash
cp .env.example .env        # optional — sets UID/GID and adapter refs
docker compose build
```

The first build is slow (~10–20 min): it compiles the R notebook stack
(tidyverse, survminer, …) and Bioconductor `limma`. Subsequent builds are
cached.

## Run

| Command | What you get |
| --- | --- |
| `docker compose up notebook` | JupyterLab at <http://127.0.0.1:8888> (no token). Both a **Python 3 (PIC-SURE)** and an **R** kernel are available. |
| `docker compose up rstudio` | RStudio Server at <http://127.0.0.1:8787> (no auth), opened in the repo — use it for the `NHLBI_BioData_Catalyst/Rstudio/*.Rmd` files. |
| `docker compose run --rm dev` | An interactive bash shell for installs/debugging. |

On the first `notebook` or `dev` run, the entrypoint installs the two
adapters from git into the shared volumes. RStudio does not run that
entrypoint, so start `notebook`/`dev` once (or install the adapters from an
RStudio Terminal) before using `library(picsure)` in RStudio.

## PIC-SURE token

Notebooks need a PIC-SURE token at runtime, supplied in the notebook or via
`.env`. The image provisions no credentials.

## Changing adapter versions

Set `PY_ADAPTER_REF` / `R_ADAPTER_REF` in `.env` (any branch, tag, or SHA).
The entrypoint keys its install stamps by ref, so the next
`docker compose up` reinstalls the changed adapter automatically. No rebuild
is required for an adapter ref change.

## Caveats

- **Named volumes don't auto-refresh from a rebuilt image.** The Python venv
  (`picsure-venv`) and R library (`picsure-r-library`) are populated from the
  image the first time each volume is created. If you rebuild the image with
  new baked dependencies, remove the volumes to pick them up:
  ```bash
  docker compose down
  docker volume rm access-to-data-using-pic-sure-api_picsure-venv \
                   access-to-data-using-pic-sure-api_picsure-r-library
  ```
  (Run `docker volume ls` to confirm the exact prefixed names.)
- Adapter ref changes are handled by the entrypoint stamps and do **not**
  need a volume reset.
- **Port clashes with the sibling adapter stacks.** The
  `pic-sure-python-adapter-hpds` and `pic-sure-r-adapter-hpds` repos each ship
  their own compose files that also publish JupyterLab on `:8888` and RStudio
  on `:8787`. Only one stack can bind a port at a time — if `docker compose up`
  here appears to start but the URL shows the wrong environment, stop the other
  stack (`docker compose down` in that repo) or remap the ports here, e.g.
  `docker compose run --rm -p 8899:8888 notebook`.
- **Some notebooks re-install the adapters themselves.** A few notebooks (e.g.
  `NHLBI_BioData_Catalyst/R/ORCHID_COVID19.ipynb`) still carry their original
  setup cells such as
  `devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main")` or
  `pip install git+...@main`. Inside this image those cells are unnecessary and
  counter-productive: the environment already installs the adapters at the
  configured refs, and the R cell additionally needs `devtools` (only `remotes`
  is baked in). **Skip those install cells** so you keep the pinned adapter
  versions.
