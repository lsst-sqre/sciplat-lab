#!/usr/bin/env bash

function copy_butler_credentials() {
    # Copy the credentials from the root-owned mounted secret to our homedir,
    # set the permissions accordingly, and repoint the environment variables.
    creddir="${HOME}/.lsst"
    mkdir -p "${creddir}"
    if [ -n "${AWS_SHARED_CREDENTIALS_FILE}" ]; then
        awsname="$(basename ${AWS_SHARED_CREDENTIALS_FILE})"
        newcreds="${creddir}/${awsname}"
        chmod 0600 "${newcreds}"
        cp "${AWS_SHARED_CREDENTIALS_FILE}" "${newcreds}"
        ORIG_AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE}"
        AWS_SHARED_CREDENTIALS_FILE="${newcreds}"
        export ORIG_AWS_SHARED_CREDENTIALS_FILE AWS_SHARED_CREDENTIALS_FILE
    fi
    if [ -n "${PGPASSFILE}" ]; then
        pgname="$(basename ${PGPASSFILE})"
        newpg="${creddir}/${pgname}"
        cp "${PGPASSFILE}" "${newpg}"
        chmod 0600 "${newpg}"
        ORIG_PGPASSFILE="${PGPASSFILE}"
        PGPASSFILE="${newpg}"
        export ORIG_PGPASSFILE PGPASSFILE
    fi
}

function copy_logging_profile() {
    profdir="${HOME}/.ipython/profile_default/startup"
    jldir="/opt/lsst/software/jupyterlab"
    mkdir -p ${profdir}
    if [ ! -e "${profdir}/20-logging.py" ]; then
	cp ${jldir}/20-logging.py ${profdir}
    fi
}

function modify_settings_files() {
    jldir="/opt/lsst/software/jupyterlab"
    python3 "${jldir}/modify_settings.py"
}

function copy_dircolors() {
    if [ !  -e "${HOME}/.dir_colors" ]; then
	cp /etc/dircolors.ansi-universal ${HOME}/.dir_colors
    fi
}

function expand_panda_tilde() {
    if [ "${PANDA_CONFIG_ROOT}" = "~" ]; then
	PANDA_CONFIG_ROOT="${HOME}"
    fi
}

function manage_access_token() {
    local tokfile="${HOME}/.access_token"
    # Clear it out each new interactive lab start.
    rm -f "${tokfile}"
    # Try the configmap first, and if that fails, use the environment
    #  variable (which eventually will go away)
    #
    # We need to put the configmap back in nublado2
    #
    local instance_tok="/opt/lsst/software/jupyterhub/tokens/access_token"
    if [ -e  "${instance_tok}" ]; then
        ln -s "${instance_tok}" "${tokfile}"
    elif [ -n "${ACCESS_TOKEN}" ]; then
        echo "${ACCESS_TOKEN}" > "${tokfile}"
    fi
}

function copy_lsst_dask() {
    mkdir -p "${HOME}/.config/dask"
    cp "/opt/lsst/software/jupyterlab/lsst_dask.yml" "${HOME}/.config/dask/"
}

function clear_dotlocal() {
    # Once every site is running a new enough nublado2 to have the new
    # RESET_USER_ENV variable instead, this can be removed.
    local dotlocal="${HOME}/.local"
    local now=$(date +%Y%m%d%H%M%S)
    if [ -d ${dotlocal} ]; then
        mv ${dotlocal} ${dotlocal}.${now}
    fi
}

function reset_user_env() {
    local now=$(date +%Y%m%d%H%M%S)
    local reloc="${HOME}/.user_env.${now}"
    mkdir -p "${reloc}"
    local moved=""
    for i in local cache jupyter; do
	if [ -d "${HOME}/.${i}" ]; then
	    mv "${HOME}/.${i}" "${reloc}"
	    moved="yes"
	fi
    done
    # If nothing was actually relocated, then do not keep the reloc directory
    if [ -z "${moved}" ]; then
	rmdir "${reloc}"
    fi
}

function copy_etc_skel() {
    es="/etc/skel"
    for i in $(find ${es}); do
        if [ "${i}" == "${es}" ]; then
            continue
        fi
        b=$(echo ${i} | cut -d '/' -f 4-)
        hb="${HOME}/${b}"
        if ! [ -e ${hb} ]; then
            cp -a ${i} ${hb}
        fi
    done
}

function start_dask_worker() {
    cmd="/opt/lsst/software/jupyterlab/lsstwrapdask.bash"
    echo "Starting dask worker: ${cmd}"
    exec ${cmd}
    exit 0 # Not reached
}

function start_noninteractive() {
    cmd="python3 -s \
          /opt/lsst/software/jupyterlab/noninteractive/noninteractive"
    echo "Starting noninteractive container: ${cmd}"
    exec ${cmd}
    exit 0 # Not reached
}

# Start of mainline code

# If DEBUG is set to a non-empty value, turn on debugging
# This will generate a lot of sort-of-spurious errors, in that Google Logging
# believes anything coming out on stderr to be an error.
if [ -n "${DEBUG}" ]; then
    set -x
fi
# Set USER if it isn't already
if [ -z "${USER}" ]; then
    USER="$(id -u -n)"
fi
export USER
# Preserve compatibility between CLEAR_DOTLOCAL and RESET_USER_ENV
if [ -n "${RESET_USER_ENV}" ]; then
    # If the newer variable is present, use it instead.
    CLEAR_DOTLOCAL=""
fi
# Clear $HOME/.local if requested
if [ -n "${CLEAR_DOTLOCAL}" ]; then
    clear_dotlocal
fi
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
# Do this early.  We want all the stuff from the stack environment for
#  all the setup we run.
source ${LOADRSPSTACK}
# Unset SUDO env vars so that Conda doesn't misbehave
unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
# Add paths
source /etc/profile.d/local05-path.sh
# Set up custom logger
copy_logging_profile
# Make ls colorization better
copy_dircolors
# Retrieve image digest
IMAGE_DIGEST=$(python -c 'import lsst.rsp;
print(lsst.rsp.get_digest())')
export IMAGE_DIGEST
# Set GitHub configuration
if [ -n "${GITHUB_EMAIL}" ]; then
    git config --global --replace-all user.email "${GITHUB_EMAIL}"
fi
if [ -n "${GITHUB_NAME}" ]; then
    git config --global --replace-all user.name "${GITHUB_NAME}"
fi
# Initialize git LFS
grep -q '^\[filter "lfs"\]$' ${HOME}/.gitconfig
rc=$?
if [ ${rc} -ne 0 ]; then
    git lfs install
fi
# Expand the tilde in PANDA_CONFIG_ROOT if needed
expand_panda_tilde
# Copy butler credentials to ${HOME}/.lsst
copy_butler_credentials
# Bump up node max storage to allow rebuild
NODE_OPTIONS=${NODE_OPTIONS:-"--max-old-space-size=7168"}
export NODE_OPTIONS

# Set timeout variable defaults
NO_ACTIVITY_TIMEOUT=${NO_ACTIVITY_TIMEOUT:-"120000"}
CULL_KERNEL_IDLE_TIMEOUT=${CULL_KERNEL_IDLE_TIMEOUT:-"43200"}
CULL_KERNEL_CONNECTED=${CULL_KERNEL_CONNECTED:-"True"}
CULL_KERNEL_INTERVAL=${CULL_KERNEL_INTERVAL:-"300"}
CULL_TERMINAL_INACTIVE_TIMEOUT=${CULL_TERMINAL_INACTIVE_TIMEOUT:-"120000"}
CULL_TERMINAL_INTERVAL=${CULL_TERMINAL_INTERVAL:-"300"}

sync
cd ${HOME}
# Do /etc/skel copy (in case we didn't provision homedir but still need to
#  populate it)
copy_etc_skel
# Replace API URL with service address if it exists
if [ -n "${HUB_SERVICE_HOST}" ]; then
    jh_proto=$(echo $JUPYTERHUB_API_URL | cut -d '/' -f -1)
    jh_path=$(echo $JUPYTERHUB_API_URL | cut -d '/' -f 4-)
    port=${HUB_SERVICE_PORT_API}
    if [ -z "${port}" ]; then
        port=${HUB_SERVICE_PORT}
        if [ -z "${port}" ]; then
            port="8081"
        fi
    fi
    jh_api="${jh_proto}//${HUB_SERVICE_HOST}:${port}/${jh_path}"
    JUPYTERHUB_API_URL=${jh_api}
fi
export JUPYTERHUB_API_URL
# Set Firefly URL and landing page
if [ -z "${EXTERNAL_URL}" ]; then
    EXTERNAL_URL=${EXTERNAL_INSTANCE_URL}
    export EXTERNAL_URL
fi
host_url=$(echo ${EXTERNAL_URL} | cut -d '/' -f 1-3)
FIREFLY_ROUTE=${FIREFLY_ROUTE:-"/firefly/"}
FIREFLY_URL="${host_url}${FIREFLY_ROUTE}"
if [ -n "${EXTERNAL_FIREFLY_URL}" ]; then
    FIREFLY_URL=${EXTERNAL_FIREFLY_URL}
fi
FIREFLY_HTML="slate.html"
export FIREFLY_URL FIREFLY_HTML
if [ -z "${JUPYTERHUB_SERVICE_PREFIX}" ]; then
    # dask.distributed gets cranky if it's not there (since it is used
    #  in lsst_dask.yml); it will be for interactive use, and whether
    #  or not the proxy dashboard URL is correct doesn't matter in a
    #  noninteractive context.
    JUPYTERHUB_SERVICE_PREFIX="/nb/user/${JUPYTERHUB_USER}"
    export JUPYTERHUB_SERVICE_PREFIX
fi
# Fetch/update magic notebook.  We want this in interactive, noninteractive,
#  and Dask pods.  We must have ${HOME} mounted but that is the case for
#  all of those scenarios.
. /opt/lsst/software/jupyterlab/refreshnb.sh
eups admin clearCache 
if [ -n "${DASK_WORKER}" ]; then
    start_dask_worker
    exit 0 # Not reached
elif [ -n "${NONINTERACTIVE}" ]; then
    start_noninteractive
    exit 0 # Not reached
else
    # All of these tasks should only be run if we are an interactive lab,
    # rather than a noninteractive lab or a Dask worker.
    copy_lsst_dask
    modify_settings_files
    manage_access_token
fi

# Set log-level to WARN so that stderr only gets WARNING and above.  We
# set up a stdout logger for lower-priority messages in
# jupyter_server_config.py .
cmd="python3 -s -m jupyter labhub \
     --ip=0.0.0.0 \
     --port=8888 \
     --no-browser \
     --notebook-dir=${HOME} \
     --hub-prefix=/nb/hub \
     --hub-host=${EXTERNAL_INSTANCE_URL} \
     --log-level=WARN \
     --ContentsManager.allow_hidden=True \
     --FileContentsManager.hide_globs=[] \
     --KernelSpecManager.ensure_native_kernel=False \
     --ServerApp.shutdown_no_activity_timeout=${NO_ACTIVITY_TIMEOUT} \
     --MappingKernelManager.cull_idle_timeout=${CULL_KERNEL_IDLE_TIMEOUT} \
     --MappingKernelManager.cull_connected=${CULL_KERNEL_CONNECTED} \
     --MappingKernelManager.cull_interval=${CULL_KERNEL_INTERVAL} \
     --MappingKernelManager.default_kernel_name=lsst \
     --TerminalManager.cull_inactive_timeout=${CULL_TERMINAL_INACTIVE_TIMEOUT} \
     --TerminalManager.cull_interval=${CULL_TERMINAL_INTERVAL}"

if [ -n "${DEBUG}" ]; then
    cmd="${cmd} --debug"
    echo "----JupyterLab env vars----"
    export -p
    echo "----JupyterLab shell functions----"
    export -f
    echo "----------------------"
fi
echo "JupyterLab command: '${cmd}'"
if [ -n "${DEBUG}" ]; then
    # Spin while waiting for interactive container use.
    # It is possible we want to do this all the time, to let us kill and
    # restart the Lab without losing the container.  We should discuss
    # how useful that would be.
    while : ; do
        ${cmd}
        d=$(date)
        echo "${d}: sleeping."
        sleep 60
    done
    exit 0 # Not reached
fi
# Start Lab
exec ${cmd}
