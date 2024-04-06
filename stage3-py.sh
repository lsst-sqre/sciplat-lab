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

# JupyterHub is flailing wildly with respect to XSRF.  4.1.5 doesn't permit
# us to get a Firefly window.
# Pin back to 4.1.4 and test new releases as they happen.

mamba install --no-banner -y \
      "jupyterhub==4.1.4" \
      "jupyterhub-base==4.1.4"

# These are the things that are not available on conda-forge.
# Note that we are not installing with `--upgrade`.  That is so that if
# lower-level layers have already installed the package, pinned to a version
# they need, we won't upgrade it.  But if it isn't already installed, we'll
# just take the latest available.  `--no-build-isolation` ensures that any
# source packages use C++ libraries from conda-forge.

# Jupyterhub 4.1.5 breaks Firefly displays.  Probably somehow XSRF related
mamba install --no-banner -y \
      "jupyterhub!=4.1.5" \
      "jupyterhub-base!=4.1.5"

pip install --no-build-isolation \
    rsp-jupyter-extensions \
    'jupyter-firefly-extensions>=4.0.0,<5' \
    git+https://github.com/lsst-sqre/lsst-rsp.git@tickets/DM-43579 \
    structlog \
    symbolicmode


# Add stack kernel
python3 -m ipykernel install --name 'LSST'

# Remove "system" kernel
stacktop="/opt/lsst/software/stack/conda/current"
rm -rf ${stacktop}/envs/${LSST_CONDA_ENV_NAME}/share/jupyter/kernels/python3

# Clear mamba and pip caches
mamba clean -a -y --no-banner
rm -rf /root/.cache/pip

# Create package version docs.
pip3 freeze > ${verdir}/requirements-stack.txt
mamba env export > ${verdir}/conda-stack.yml
