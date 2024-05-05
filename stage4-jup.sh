#!/bin/sh
set -e

_disable_ext () {
    jupyter labextension disable $1
    jupyter labextension lock $1  # Lock is new in jl 4.1
}

source ${LOADRSPSTACK}
# File sharing doesn't work in the RSP environment; remove the extension.
_disable_ext "@jupyterlab/filebrowser-extension:share-file"
# And Jupyter News is just obnoxious
_disable_ext "@jupyterlab/apputils-extension:announcements"
# Our RSP menu supersedes the Hub menu items
_disable_ext "@jupyterlab/hub-extension:menu"

# List installed labextensions and put them into a format we could consume
#  for installation
jupyter labextension list 2>&1 | \
      grep '^      ' | grep -v ':' | grep -v 'OK\*' | \
      awk '{print $1,$2}' | tr ' ' '@' | sort > ${verdir}/labext.txt
