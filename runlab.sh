#!/usr/bin/env bash

# This script is a stopgap until we separate the DM stack and the Python
# responsible for running JupyterLab, and can use the entrypoint directly,
# using reset_user_env() in the LabRunner class, and not requiring knowledge
# of the stack-loading magic.

function reset_user_env() {
    local now=$(date +%Y%m%d%H%M%S)
    local reloc="${HOME}/.user_env.${now}"
    mkdir -p "${reloc}"
    local moved=""
    # Dirs
    for i in cache conda local jupyter; do
        if [ -d "${HOME}/.${i}" ]; then
            mv "${HOME}/.${i}" "${reloc}"
            moved="yes"
        fi
    done
    # Files; they're not necessarily at the top level
    if [ -f "${HOME}/notebooks/.user_setups" ]; then
	mkdir -p "${reloc}/notebooks"
        mv "${HOME}/notebooks/.user_setups" "${reloc}/notebooks/user_setups"
        moved="yes"
    fi
    # If nothing was actually relocated, then do not keep the reloc directory
    if [ -z "${moved}" ]; then
        rmdir "${reloc}"
    fi
}

# Start of mainline code
if [ -n "${RESET_USER_ENV}" ]; then
    reset_user_env
fi
# LOADRSPSTACK should be set, but if not...
if [ -z "${LOADRSPSTACK}" ]; then
    if [ -e "/opt/lsst/software/rspstack/loadrspstack.bash" ]; then
        LOADRSPSTACK="/opt/lsst/software/rspstack/loadrspstack.bash"
    else
        LOADRSPSTACK="/opt/lsst/software/stack/loadLSST.bash"
    fi
fi
export LOADRSPSTACK
source ${LOADRSPSTACK}
source /etc/profile.d/local05-path.sh

# Now we transfer control to the Python entrypoint "runlab", defined
# as part of lsst.rsp (in the lsst-rsp package).

exec runlab

