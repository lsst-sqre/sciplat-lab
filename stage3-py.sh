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
mamba install --no-banner -y \
      "jupyterlab>=3,<3.4" \
      "rubin-env==${rubin_env_ver}" \
      jupyterhub==2.2.0 \
      ipykernel \
      jupyter-server-proxy \
      jupyter-packaging \
      geoviews \
      cookiecutter \
      nbval \
      pyshp \
      pypandoc \
      astroquery \
      ipywidgets \
      ipyevents \
      bokeh \
      cloudpickle \
      fastparquet \
      paramnb \
      ginga \
      bqplot \
      ipyvolume \
      papermill \
      dask \
      gcsfs \
      snappy \
      distributed \
      dask-kubernetes \
      "holoviews[recommended]" \
      datashader \
      python-snappy \
      graphviz \
      mysqlclient \
      hvplot \
      intake \
      intake-parquet \
      toolz \
      partd \
      nbdime \
      dask_labextension \
      numba \
      awkward \
      awkward-numba \
      pyvo \
      jupyterlab_iframe \
      jupyterlab_widgets \
      astrowidgets \
      sidecar \
      python-socketio \
      freetype-py \
      terminado \
      "nodejs>=16" \
      yarn \
      jedi \
      xarray \
      jupyter_bokeh \
      pyviz_comms \
      pythreejs \
      bqplot \
      jupyterlab_execute_time \
      ipympl \
      ciso8601 \
      plotly \
      dash \
      jupyter-dash
# These are the things that are not available on conda-forge.
pip install --upgrade \
       nbconvert[webpdf] \
       socketIO-client \
       nclib \
       jupyterlab_hdf \
       lsst-efd-client \
       jupyter_firefly_extensions \
       lsst-rsp \
       rsp-jupyter-extensions

# Add stack kernel
python3 -m ipykernel install --name 'LSST'

# Remove "system" kernel
stacktop="/opt/lsst/software/stack/conda/current"
rm -rf ${stacktop}/envs/${LSST_CONDA_ENV_NAME}/share/jupyter/kernels/python3

# Clear Mamba and pip caches
mamba clean -a -y
rm -rf /root/.cache/pip

# Create package version docs.
pip3 freeze > ${verdir}/requirements-stack.txt
mamba env export > ${verdir}/conda-stack.yml
