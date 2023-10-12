#!/bin/sh
set -e
source ${LOADRSPSTACK}
# File sharing doesn't work in the RSP environment; remove the extension.
jupyter labextension disable "@jupyterlab/filebrowser-extension:share-file"
# And Jupyter News is just obnoxious
jupyter labextension disable "@jupyterlab/apputils-extension:announcements"
# Our RSP menu supersedes the Hub menu items
jupyter labextension disable "@jupyterlab/hub-extension:menu"

# List installed labextensions and put them into a format we could consume
#  for installation
jupyter labextension list 2>&1 | \
      grep '^      ' | grep -v ':' | grep -v 'OK\*' | \
      awk '{print $1,$2}' | tr ' ' '@' | sort > ${verdir}/labext.txt
