#!/bin/sh
set -e

#This commented-out bit, plus changing the definition of LOADRSPSTACK in
# Dockerfile.template, will clone the environment rather than installing
# into the stack environment itself.  This adds 60% or so to the container
# size.
#
# source ${LOADSTACK}
# rspname="rsp-${LSST_CONDA_ENV_NAME}"
# mamba create --name ${rspname} --clone ${LSST_CONDA_ENV_NAME}
#
source ${LOADRSPSTACK}

# Mamba is compatible with conda, but much faster
if [ -z "$(which mamba)" ]; then
    conda install -y mamba
fi

# Never allow the installation to upgrade rubin_env.  Generally enforcing
# the pin is only needed for releases, where the current version may have
# moved ahead.
rubin_env_ver=$(mamba list rubin-env$ --no-banner --json \
                    | jq -r '.[0].version')
# Do the rest of the installation.
mamba install --no-banner -y \
     "rubin-env-rsp==${rubin_env_ver}"

# Force this temporarily, because we need a newer version than ships with
# rubin-env 8.0.0
mamba install --no-banner -y 'firefly-client>=3.0.1'

# As with conda->mamba, uv is compatible with pip but much faster.  It
# matters less here, of course, because there are many fewer
# pip-installed packages.
pip install uv

# These are the things that are not available on conda-forge.
# Note that we are not installing with `--upgrade`.  That is so that if
# lower-level layers have already installed the package, pinned to a version
# they need, we won't upgrade it.  But if it isn't already installed, we'll
# just take the latest available.  `--no-build-isolation` ensures that any
# source packages use C++ libraries from conda-forge.

# "--no-build-isolation" means we're also responsible for the dependencies
# not already provided by something in the conda env.  In this case,
# structlog and symbolicmode from lsst-rsp.

uv pip install --no-build-isolation \
    rsp-jupyter-extensions \
    'jupyter-firefly-extensions>=4.1.1' \
    'lsst-rsp>=0.5.1' \
    structlog \
    'symbolicmode<3'

# Add stack kernel
python3 -m ipykernel install --name 'LSST'

# Remove "system" kernel
stacktop="/opt/lsst/software/stack/conda/current"
rm -rf ${stacktop}/envs/${LSST_CONDA_ENV_NAME}/share/jupyter/kernels/python3

# Clear mamba, pip, and uv caches
mamba clean -a -y --no-banner
pip cache purge
uv cache clean

# Create package version docs.
uv pip freeze > ${verdir}/requirements-stack.txt
mamba env export > ${verdir}/conda-stack.yml
