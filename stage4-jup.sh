#!/bin/sh
set -e
source ${LOADRSPSTACK}

# Server, notebook, and lab extensions
svxt="jupyter_firefly_extensions"
# No notebook extensions
lbxt="jupyter_firefly_extensions"

# Don't understand why
#  jupyter serverextension enable panel.io.jupyter_server_extension
# fails here, but we'll just put it into the jupyter_server_config.json
for s in $svxt; do
    jupyter serverextension enable ${s} --py --sys-prefix
done
for l in ${lbxt}; do
    jupyter labextension install ${l} --no-build
done

for l in ${lbxt} ; do
    jupyter labextension enable ${l}
done
# File sharing doesn't work in the RSP environment, so remove the extension.
jupyter labextension disable \
	"@jupyterlab/filebrowser-extension:share-file"

# Rebuild the world.  Again.
jupyter lab build --dev-build=False --minimize=False

# List installed labextensions and put them into a format we could consume
#  for installation
jupyter labextension list 2>&1 | \
      grep '^      ' | grep -v ':' | grep -v 'OK\*' | \
      awk '{print $1,$2}' | tr ' ' '@' | sort > ${verdir}/labext.txt
