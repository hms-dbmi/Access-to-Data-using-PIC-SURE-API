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
