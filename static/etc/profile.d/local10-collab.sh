#!/bin/sh
if [ -n "${NUBLADO_COLLAB_DIR}" ]; then
    shadow_collab="${HOME}/collab"
    if ! [ -e "${shadow_collab}" ]; then
	ln -s "${NUBLADO_COLLAB_DIR}" "${shadow_collab}"
    fi
fi
