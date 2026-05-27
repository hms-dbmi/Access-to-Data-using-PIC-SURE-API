# Notebooks Docker Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `docker-compose.yml` to `Access-to-Data-using-PIC-SURE-API/` that stands up a combined R + Python environment able to run every v3-adapter notebook, with both PIC-SURE adapters installed from git and the repo files editable in place.

**Architecture:** One image built from `rocker/rstudio:4.4` (R + RStudio + pandoc), extended with a Python venv at `/opt/venv`, JupyterLab, both Jupyter kernels, the heavy R + Python notebook stacks (baked at build), and the two PIC-SURE adapters (installed from git at entrypoint time, keyed by ref). Three compose services — `dev`, `notebook`, `rstudio` — share the image and three named volumes. `RETICULATE_PYTHON=/opt/venv/bin/python` makes the Python adapter ref authoritative for both the Python kernel and R/reticulate.

**Tech Stack:** Docker / docker compose, rocker/rstudio (R 4.4, Ubuntu noble), `uv`, JupyterLab + IRkernel + ipykernel, `pak`, Bioconductor (`limma`).

**Spec:** `docs/superpowers/specs/2026-05-26-notebooks-docker-environment-design.md`

---

## File Structure

All new files, inside the `Access-to-Data-using-PIC-SURE-API/` repo:

- `docker/entrypoint.sh` — first-run adapter install (git, ref-keyed stamps), then exec the command. Used by `dev`/`notebook` only.
- `docker/Dockerfile` — the combined image: base, system deps, uv, user remap, Python venv + kernels, heavy R + Python stacks, RStudio session config.
- `docker-compose.yml` — `x-common` anchor + `dev` / `notebook` / `rstudio` services + named volumes.
- `.env.example` — `UID`/`GID` and the overridable adapter refs.
- `docs/development-docker.md` — how to build, run, override refs, and the known caveats.

`TODO.md` (root, gitignored) and `.gitignore` already carry the "switch `R_ADAPTER_REF` back to `main` before release" note — no change needed here.

---

## Task 1: Entrypoint script

**Files:**
- Create: `docker/entrypoint.sh`

- [ ] **Step 1: Write the entrypoint**

```bash
#!/usr/bin/env bash
# Entrypoint for the `dev` and `notebook` services:
#   1. Install the two PIC-SURE adapters from git on first run, keyed by
#      ref so a ref change re-triggers the install.
#   2. Exec the requested command (bash for `dev`, jupyter for `notebook`).
#
# The `rstudio` service overrides ENTRYPOINT to rocker's /init, so this
# does NOT run there. Adapters are installed by the first dev/notebook
# run that shares the same named volumes, or manually from an RStudio
# terminal pane.

set -euo pipefail

VENV_DIR="${VENV_DIR:-/opt/venv}"
R_LIB="${R_LIBS_USER:-/opt/R/library}"
PY_REF="${PY_ADAPTER_REF:-main}"
R_REF="${R_ADAPTER_REF:-query_v3}"

PY_STAMP="${VENV_DIR}/.py-adapter-${PY_REF}.stamp"
R_STAMP="${R_LIB}/.r-adapter-${R_REF}.stamp"

if [ ! -f "${PY_STAMP}" ]; then
    echo "==> Installing PIC-SURE python adapter (ref: ${PY_REF})"
    uv pip install --python "${VENV_DIR}/bin/python" --no-cache \
        "picsure @ git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@${PY_REF}"
    touch "${PY_STAMP}"
fi

if [ ! -f "${R_STAMP}" ]; then
    echo "==> Installing PIC-SURE R adapter (ref: ${R_REF})"
    R --quiet --no-save -e \
        "pak::pkg_install('github::hms-dbmi/pic-sure-r-adapter-hpds@${R_REF}')"
    touch "${R_STAMP}"
fi

exec "$@"
```

- [ ] **Step 2: Make it executable and syntax-check it**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
chmod +x docker/entrypoint.sh
bash -n docker/entrypoint.sh && echo "SYNTAX OK"
```
Expected: prints `SYNTAX OK` with no errors.

- [ ] **Step 3: Commit**

```bash
git add docker/entrypoint.sh
git commit -m "Add notebooks container entrypoint (git adapter install)"
```

---

## Task 2: Dockerfile

**Files:**
- Create: `docker/Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

```dockerfile
# syntax=docker/dockerfile:1.7
#
# Combined R + Python environment for the PIC-SURE example notebooks.
# Runs every v3-adapter notebook (all R notebooks + the 9 ported
# NHLBI_BioData_Catalyst/python notebooks) via JupyterLab and RStudio.
#
# Base: rocker/rstudio:4.4 — R 4.4 + RStudio Server + pandoc on Ubuntu
# noble. We add a Python venv, JupyterLab, both Jupyter kernels, the
# heavy R + Python notebook stacks (baked here), and the two PIC-SURE
# adapters (installed from git at entrypoint time).

FROM rocker/rstudio:4.4

ENV DEBIAN_FRONTEND=noninteractive

# System build deps for the R notebook packages (curl/ssl/xml2/fonts/
# harfbuzz/png/tiff/jpeg/icu/zmq, cmake for source builds), git +
# tini, and Python for the Jupyter kernel + reticulate.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        ca-certificates \
        curl \
        tini \
        less \
        vim-tiny \
        cmake \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libgit2-dev \
        libssh2-1-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libtiff5-dev \
        libjpeg-dev \
        libicu-dev \
        libzmq3-dev \
        zlib1g-dev \
        python3 \
        python3-venv \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Pinned uv (no curl|sh). Builds the Python venv at /opt/venv and
# installs the python adapter at entrypoint time.
COPY --from=ghcr.io/astral-sh/uv:0.7.13 /uv /uvx /usr/local/bin/

# Remap the rocker `rstudio` user (UID 1000) so bind-mounted files land
# with host ownership on Linux. Mostly a no-op on macOS Docker Desktop.
ARG USER_UID=1000
ARG USER_GID=1000
RUN if [ "$(id -u rstudio)" != "${USER_UID}" ]; then usermod  -u ${USER_UID} rstudio; fi \
 && if [ "$(id -g rstudio)" != "${USER_GID}" ]; then groupmod -g ${USER_GID} rstudio; fi \
 && chown -R ${USER_UID}:${USER_GID} /home/rstudio

# Trust the bind-mounted workspace for all users.
RUN git config --system --add safe.directory /workspace

# Adapter git refs — overridable at build time and via .env at runtime.
# R defaults to query_v3 (its v3 work is not yet on main); see
# /workspace/TODO.md for the switch-to-main task.
ARG PY_ADAPTER_REF=main
ARG R_ADAPTER_REF=query_v3

# Persistent locations live on named volumes (see docker-compose.yml).
# RETICULATE_PYTHON points R/reticulate at the same /opt/venv where the
# Python adapter is installed, so PY_ADAPTER_REF drives both the Python
# kernel and R; the R adapter's own git-pinned managed venv is bypassed.
ENV R_LIBS_USER=/opt/R/library \
    R_LIBS_SITE=/opt/R/library \
    UV_CACHE_DIR=/home/rstudio/.cache/uv \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    VENV_DIR=/opt/venv \
    RETICULATE_PYTHON=/opt/venv/bin/python \
    PY_ADAPTER_REF=${PY_ADAPTER_REF} \
    R_ADAPTER_REF=${R_ADAPTER_REF} \
    PATH=/opt/venv/bin:/home/rstudio/.local/bin:$PATH

RUN mkdir -p /opt/R/library /opt/venv /home/rstudio/.cache/uv \
 && chown -R rstudio:rstudio /opt/R/library /opt/venv /home/rstudio

# Ensure the writable user library is on .libPaths() ahead of the
# read-only system tree (append to rocker's Rprofile.site).
RUN printf '\n%s\n' \
    'local({' \
    '  user_lib <- Sys.getenv("R_LIBS_USER", "/opt/R/library")' \
    '  if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)' \
    '  .libPaths(c(user_lib, .libPaths()))' \
    '})' \
    >> /usr/local/lib/R/etc/Rprofile.site

# JupyterLab + LSP in the system Python so the notebook server is always
# present regardless of the /opt/venv volume state. The data-science
# kernel itself lives in /opt/venv, below.
RUN pip install --break-system-packages --no-cache-dir \
        jupyterlab \
        jupyterlab-lsp \
        'python-lsp-server[all]'

# Python data-science venv: the JupyterLab "Python 3 (PIC-SURE)" kernel
# and everything the python notebooks import. The PIC-SURE python
# adapter is added at entrypoint time from git. The kernelspec is
# registered to /usr/local (image) so it persists even though the venv
# interpreter lives on the named volume.
RUN uv venv /opt/venv --python /usr/bin/python3 \
 && uv pip install --python /opt/venv/bin/python --no-cache \
        ipykernel \
        pandas \
        numpy \
        matplotlib \
        seaborn \
        matplotlib-venn \
        statsmodels \
        scipy \
 && /opt/venv/bin/python -m ipykernel install \
        --prefix=/usr/local \
        --name picsure-py \
        --display-name "Python 3 (PIC-SURE)" \
 && chown -R rstudio:rstudio /opt/venv

# R bootstrap + notebook stack. pak pulls binary packages from Posit
# Package Manager. IRkernel is registered system-wide so JupyterLab
# sees the R kernel. Bioconductor limma via BiocManager. This is the
# slow layer (~10-20 min on a cold build).
RUN R -e "install.packages('pak', repos = 'https://packagemanager.posit.co/cran/__linux__/noble/latest')" \
 && R -e "pak::pkg_install(c('IRkernel', 'languageserver', 'reticulate', 'tidyverse', 'survival', 'survminer', 'cmprsk', 'quantreg', 'DescTools', 'arsenal', 'coin', 'kableExtra', 'ggtext', 'ggrepel', 'BiocManager'))" \
 && R -e "BiocManager::install('limma', update = FALSE, ask = FALSE)" \
 && R -e "IRkernel::installspec(user = FALSE)" \
 && chown -R rstudio:rstudio /opt/R/library

# RStudio: open sessions directly in the bind-mounted repo.
RUN echo "session-default-working-dir=/workspace"  >> /etc/rstudio/rsession.conf \
 && echo "session-default-new-project-dir=/workspace" >> /etc/rstudio/rsession.conf

RUN printf '\nif (interactive() && file.exists("/workspace")) setwd("/workspace")\n' \
        >> /home/rstudio/.Rprofile \
 && chown rstudio:rstudio /home/rstudio/.Rprofile

USER rstudio
WORKDIR /workspace

COPY --chown=rstudio:rstudio docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Default entrypoint covers `dev` and `notebook`. The `rstudio` service
# overrides ENTRYPOINT back to rocker's /init.
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
```

- [ ] **Step 2: Validate Dockerfile syntax without a full build**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
docker build --check -f docker/Dockerfile .
```
Expected: `Check complete, no warnings found.` (or only style warnings, no errors). The full build happens in Task 6.

- [ ] **Step 3: Commit**

```bash
git add docker/Dockerfile
git commit -m "Add combined R + Python notebooks Dockerfile"
```

---

## Task 3: docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write the compose file**

```yaml
# Docker environment for the PIC-SURE example notebooks.
#
# Three services share one image (docker/Dockerfile):
#   dev       — interactive bash shell.
#   notebook  — JupyterLab on http://127.0.0.1:8888 (Python + R kernels).
#   rstudio   — RStudio Server on http://127.0.0.1:8787 (no auth).
#
# All bind-mount this repo at /workspace (editable) and share named
# volumes for the Python venv, the R library, and the uv cache.
#
# Quick start:
#   cp .env.example .env             # optional; sets UID/GID + refs
#   docker compose build
#   docker compose up notebook       # JupyterLab on :8888
#   docker compose up rstudio        # RStudio on :8787
#   docker compose run --rm dev      # shell

x-common: &common
  image: picsure-notebooks:latest
  build:
    context: .
    dockerfile: docker/Dockerfile
    args:
      USER_UID: ${UID:-1000}
      USER_GID: ${GID:-1000}
      PY_ADAPTER_REF: ${PY_ADAPTER_REF:-main}
      R_ADAPTER_REF: ${R_ADAPTER_REF:-query_v3}
  env_file:
    - path: .env
      required: false
  volumes:
    - .:/workspace
    - picsure-venv:/opt/venv
    - picsure-r-library:/opt/R/library
    - uv-cache:/home/rstudio/.cache/uv
  working_dir: /workspace

services:
  dev:
    <<: *common
    stdin_open: true
    tty: true
    command: ["bash"]

  notebook:
    <<: *common
    ports:
      - "127.0.0.1:8888:8888"
    command:
      - jupyter
      - lab
      - --ip=0.0.0.0
      - --port=8888
      - --no-browser
      - --ServerApp.token=
      - --ServerApp.password=
      - --ServerApp.root_dir=/workspace

  rstudio:
    <<: *common
    # rocker's s6 init must start as root to set up its supervisor
    # files; it drops to the `rstudio` user before launching
    # rstudio-server. Bypass our entrypoint so adapter installs don't
    # gate UI startup — open a Terminal pane and let the first
    # dev/notebook run (shared volumes) install the adapters, or run
    # the install commands manually.
    entrypoint: ["/init"]
    command: []
    user: root
    environment:
      DISABLE_AUTH: "true"
      ROOT: "false"
      USER: rstudio
    ports:
      - "127.0.0.1:8787:8787"

volumes:
  picsure-venv:
  picsure-r-library:
  uv-cache:
```

- [ ] **Step 2: Validate the compose file and verify interpolation**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
docker compose config >/dev/null && echo "COMPOSE OK"
docker compose config | grep -E "R_ADAPTER_REF|PY_ADAPTER_REF"
```
Expected: prints `COMPOSE OK`, and the build args show `PY_ADAPTER_REF: main` and `R_ADAPTER_REF: query_v3` (the defaults, since no `.env` exists yet).

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "Add docker-compose with dev, notebook, and rstudio services"
```

---

## Task 4: .env.example

**Files:**
- Create: `.env.example`

- [ ] **Step 1: Write the example env file**

```bash
# Copy to .env to customize. All values are optional — the defaults in
# docker-compose.yml / docker/Dockerfile apply if .env is absent.

# Host UID/GID so files written through the bind mount land with your
# ownership on Linux. Ignored on macOS Docker Desktop. Capture with:
#   printf 'UID=%s\nGID=%s\n' "$(id -u)" "$(id -g)" >> .env
UID=1000
GID=1000

# Git refs the PIC-SURE adapters are installed from. The R adapter
# temporarily tracks query_v3 (its v3 work is not yet on main); see
# TODO.md. Changing a ref takes effect on the next `docker compose up`
# (the entrypoint re-installs because stamps are keyed by ref).
PY_ADAPTER_REF=main
R_ADAPTER_REF=query_v3
```

- [ ] **Step 2: Verify it does not get committed as a real `.env`**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
test -f .env && echo "WARNING: a real .env exists" || echo "no real .env — good"
ls .env.example && echo "example present"
```
Expected: `no real .env — good` and `example present`.

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "Add .env.example for notebooks Docker environment"
```

---

## Task 5: Usage documentation

**Files:**
- Create: `docs/development-docker.md`

- [ ] **Step 1: Write the doc**

````markdown
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
````

- [ ] **Step 2: Verify the doc renders as valid markdown (no broken code fences)**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
grep -c '```' docs/development-docker.md
```
Expected: an **even** number (every fence opened is closed). The outer doc uses ```` ```` ```` fences around inner ``` blocks, so confirm the file opens in a markdown previewer without leaking.

- [ ] **Step 3: Commit**

```bash
git add docs/development-docker.md
git commit -m "Document the notebooks Docker environment"
```

---

## Task 6: Build and smoke-test the environment

This is the acceptance verification from the spec. It builds the image and
checks both kernels and the adapter imports. No code changes — if a check
fails, fix the offending file from the earlier task and re-run.

**Files:** none (verification only)

- [ ] **Step 1: Build the image**

Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
docker compose build
```
Expected: build completes without error. (Slow on a cold cache — see the doc.)

- [ ] **Step 2: Verify both Jupyter kernels are registered**

Run:
```bash
docker compose run --rm --entrypoint jupyter notebook kernelspec list
```
Expected: the list includes `picsure-py` (Python 3 (PIC-SURE)) and `ir` (R).

- [ ] **Step 3: Verify the Python adapter imports (triggers entrypoint install)**

Run:
```bash
docker compose run --rm dev python -c "import picsure; print('picsure', picsure.__name__, 'OK')"
```
Expected: first run prints the `==> Installing PIC-SURE python adapter (ref: main)` line, then `picsure picsure OK`.

- [ ] **Step 4: Verify the R adapter loads and reticulate uses /opt/venv**

Run:
```bash
docker compose run --rm dev R --quiet --no-save -e \
  "suppressPackageStartupMessages(library(picsure)); cat(reticulate::py_config()\$python, '\n')"
```
Expected: prints `==> Installing PIC-SURE R adapter (ref: query_v3)` on first run, then a path under `/opt/venv/bin/python`.

- [ ] **Step 5: Verify the heavy R notebook stack is present**

Run:
```bash
docker compose run --rm dev R --quiet --no-save -e \
  "for (p in c('tidyverse','survminer','cmprsk','quantreg','DescTools','arsenal','coin','kableExtra','ggtext','ggrepel','limma')) suppressPackageStartupMessages(library(p, character.only = TRUE)); cat('R STACK OK\n')"
```
Expected: prints `R STACK OK` with no "there is no package called" errors.

- [ ] **Step 6: Verify the Python notebook stack is present**

Run:
```bash
docker compose run --rm dev python -c "import pandas, numpy, matplotlib, seaborn, matplotlib_venn, statsmodels, scipy; print('PY STACK OK')"
```
Expected: prints `PY STACK OK`.

- [ ] **Step 7: Verify JupyterLab and RStudio actually serve (manual)**

Run, then open the URLs in a browser, then Ctrl-C:
```bash
docker compose up notebook    # open http://127.0.0.1:8888 — JupyterLab loads, both kernels selectable
docker compose up rstudio     # open http://127.0.0.1:8787 — RStudio loads (no login), working dir is /workspace
```
Expected: both UIs load. In RStudio's Console, `library(picsure)` works after the adapters were installed by a prior `dev`/`notebook` run (shared volumes).

- [ ] **Step 8: Commit the verified plan checkpoint**

No file changes; the environment is verified. If any earlier file needed a
fix, it was committed in its own task. Optionally tag completion:
```bash
git commit --allow-empty -m "Verify notebooks Docker environment (build + kernels + adapters)"
```
