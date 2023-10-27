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
#mamba install --no-banner -y \
#     "rubin-env-rsp==${rubin_env_ver}"

# Install rubin-rsp-env by hand for now.
mamba install --no-banner -y \
   astroplan \
   'astrowidgets>=0.3' \
   awkward \
   awkward-pandas \
   black \
   bokeh \
   bqplot \
   ciso8601 \
   cloudpickle \
   cookiecutter \
   'dash>=2.11' \
   datashader \
   fastparquet \
   ffmpeg \
   freetype-py \
   gcsfs \
   geoviews \
   gh \
   'ginga>=3' \
   graphviz \
   hatch-jupyter-builder \
   hatch-nodejs-version \
   hatchling \
   hdf5plugin \
   holoviews \
   httpx \
   hvplot \
   imagemagick \
   intake \
   intake-parquet \
   ipyevents \
   ipykernel \
   ipympl \
   ipyvolume \
   ipywidgets \
   'isort!=5.11.0' \
   jedi \
   jupyter \
   jupyter-packaging \
   jupyter-resource-usage \
   jupyter-server-proxy \
   jupyter_bokeh \
   jupyterhub \
   'jupyterlab>=4,<5' \
   jupyterlab_execute_time \
   jupyterlab_iframe \
   jupyterlab_widgets \
   jupyterlab-h5web \
   jupyterlab-variableinspector \
   lsst-efd-client \
   mamba \
   mypy \
   mysqlclient \
   nb_black \
   nbconvert-webpdf \
   nbval \
   'nodejs>=16' \
   'panel>=0.12.1' \
   papermill \
   paramnb \
   partd \
   pep8 \
   plotly \
   pre-commit \
   pyflakes \
   pypandoc \
   pyshp \
   python-snappy \
   python-socketio \
   pythreejs \
   pyviz_comms \
   pyvo \
   ripgrep \
   sidecar \
   snappy \
   terminado \
   toolz \
   wget \
   xarray \
   yarn

# These are the things that are not available on conda-forge.
# Note that we are not installing with `--upgrade`.  That is so that if
# lower-level layers have already installed the package, pinned to a version
# they need, we won't upgrade it.  But if it isn't already installed, we'll
# just take the latest available.  `--no-build-isolation` ensures that any
# source packages use C++ libraries from conda-forge.
#
# nbdime is on conda-forge, but not a JL4-compatible one just yet (nor is
# there a non-prelease version on pypi yet)
pip install --pre nbdime
pip install --no-build-isolation \
    'jupyter-firefly-extensions>=4.0.0,<5' \
    lsst-rsp \
    git+https://github.com/lsst-sqre/rsp-jupyter-extensions

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
