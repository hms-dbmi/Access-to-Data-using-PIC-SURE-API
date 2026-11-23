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
# tini, and Python for the Jupyter kernel + reticulate. libpython3.12-dev
# ships libpython3.12.so.1.0 — the embeddable shared library reticulate
# must dlopen to run R's `library(picsure)`; the stdlib/minimal packages
# alone do not include it, so without -dev reticulate reports
# "Python shared library not found".
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
        libpython3.12-dev \
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
#
# RETICULATE_PYTHON points R/reticulate at the same /opt/venv where the
# Python adapter is installed, so PY_ADAPTER_REF is the single source of
# truth for the Python adapter across both the Python kernel and R. In
# reticulate's py_discover_config, RETICULATE_PYTHON is honored before
# any managed-venv logic, so the R adapter's own git-pinned py_require()
# spec in zzz.R (.PICSURE_PY_SPEC, hard-coded to @main) is effectively
# inert here. RETICULATE_USE_MANAGED_VENV=no makes that opt-out explicit
# rather than relying on the variable's absence.
#
# UV_PYTHON pins uv to the apt-installed interpreter so a stray `uv`
# invocation in the dev shell never tries to fetch a managed Python
# (which UV_PYTHON_DOWNLOADS=never would reject).
ENV R_LIBS_USER=/opt/R/library \
    R_LIBS_SITE=/opt/R/library \
    UV_CACHE_DIR=/home/rstudio/.cache/uv \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PYTHON=/usr/bin/python3 \
    VENV_DIR=/opt/venv \
    RETICULATE_PYTHON=/opt/venv/bin/python \
    RETICULATE_USE_MANAGED_VENV=no \
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

# Python data-science venv at /opt/venv: the JupyterLab server, the
# "Python 3 (PIC-SURE)" kernel, and everything the python notebooks
# import. The PIC-SURE python adapter is added at entrypoint time.
#
# JupyterLab MUST live in this venv, not in the system Python. jupyter
# launches the stock `python3` kernelspec via a bare `python` argv that
# jupyter_client rewrites to the *server's* own sys.executable; a
# system-Python server therefore starts notebook kernels in system
# Python, where pandas/numpy/etc. are absent ("No module named
# 'pandas'"). Running the server from the venv makes that rewrite
# resolve to /opt/venv/bin/python. As belt-and-suspenders we also
# re-register the `python3` kernelspec with an absolute interpreter path
# (overwriting the stock one in /opt/venv/share) so notebooks — whose
# saved kernel name is `python3` — bind to the venv unconditionally.
RUN uv venv /opt/venv --python /usr/bin/python3 \
 && uv pip install --python /opt/venv/bin/python --no-cache \
        jupyterlab \
        jupyterlab-lsp \
        'python-lsp-server[all]' \
        ipykernel \
        pandas \
        numpy \
        matplotlib \
        seaborn \
        matplotlib-venn \
        statsmodels \
        scipy \
 && /opt/venv/bin/python -m ipykernel install \
        --prefix=/opt/venv \
        --name python3 \
        --display-name "Python 3 (PIC-SURE)" \
 && chown -R rstudio:rstudio /opt/venv

# R bootstrap + notebook stack via install.packages against Posit
# Package Manager (the same approach the sibling R-adapter image uses).
#
# We deliberately do NOT use pak here: on arm64 (aarch64) Ubuntu, P3M
# has no prebuilt binaries, so it serves source tarballs, and pak's
# subprocess misclassifies the source tarball as a binary and aborts
# with "is not a valid binary, it is missing <pkg>/Meta/package.rds".
# install.packages handles the source fallback correctly (compiling
# from source, which is why all the -dev libs above are present).
# `remotes` is installed for the entrypoint's install_github of the R
# adapter. IRkernel is registered system-wide so JupyterLab sees the R
# kernel. Bioconductor limma via BiocManager. This is the slow layer
# (source compilation on arm64 can take well over 20 min on a cold
# build; cached afterward). The final setdiff() check fails the build
# loudly if any package did not install, since install.packages only
# warns on a failed compile.
RUN R -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/noble/latest')); \
          pkgs <- c('remotes', 'IRkernel', 'languageserver', 'reticulate', 'tidyverse', 'survival', 'survminer', 'cmprsk', 'quantreg', 'DescTools', 'arsenal', 'coin', 'kableExtra', 'ggtext', 'ggrepel', 'BiocManager'); \
          install.packages(pkgs); \
          BiocManager::install('limma', update = FALSE, ask = FALSE); \
          missing <- setdiff(c(pkgs, 'limma'), rownames(installed.packages())); \
          if (length(missing)) stop('Failed to install: ', paste(missing, collapse = ', '))" \
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
