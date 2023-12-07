#!/usr/bin/env bash

function copy_butler_credentials() {
    # Copy the credentials from the root-owned mounted secret to our homedir,
    # set the permissions accordingly, and repoint the environment variables.
    creddir="${HOME}/.lsst"
    mkdir -p "${creddir}"
    chmod 0700 "${creddir}"
    if [ -n "${AWS_SHARED_CREDENTIALS_FILE}" ]; then
        awsname="$(basename ${AWS_SHARED_CREDENTIALS_FILE})"
        newcreds="${creddir}/${awsname}"
	python /opt/lsst/software/jupyterlab/confmerge.py ini "${AWS_SHARED_CREDENTIALS_FILE}" "${newcreds}"
        ORIG_AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE}"
        AWS_SHARED_CREDENTIALS_FILE="${newcreds}"
        export ORIG_AWS_SHARED_CREDENTIALS_FILE AWS_SHARED_CREDENTIALS_FILE
    fi
    if [ -n "${PGPASSFILE}" ]; then
        pgname="$(basename ${PGPASSFILE})"
        newpg="${creddir}/${pgname}"
	python /opt/lsst/software/jupyterlab/confmerge.py pgpass "${PGPASSFILE}" "${newpg}"
        ORIG_PGPASSFILE="${PGPASSFILE}"
        PGPASSFILE="${newpg}"
        export ORIG_PGPASSFILE PGPASSFILE
    fi
}

function copy_logging_profile() {
    profdir="${HOME}/.ipython/profile_default/startup"
    jldir="/opt/lsst/software/jupyterlab"
    mkdir -p ${profdir}
    logfile="${profdir}/20-logging.py"
    # If the logging directive file doesn't exist, or is unchanged from
    # an earlier version, then replace it with the current one.  If it
    # has changed, assume the user knew what they were doing and leave it
    # untouched.
    #
    # previous_sums is a space-separated list of former checksums of the
    # directive file in question.
    previous_sums="2997fe99eb12846a1b724f0b82b9e5e6acbd1d4c29ceb9c9ae8f1ef5503892ec"
    if [ ! -e "${logfile}" ]; then
        cp ${jldir}/20-logging.py ${logfile}
    else
        for p in ${previous_sums}; do
            s=$(sha256sum "${logfile}" | awk '{print $1}')
            if [ "${s}" == "${p}" ]; then
                cp ${jldir}/20-logging.py ${logfile}
                break
            fi
        done
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
    # Files
    for i in user_setups; do
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

function set_cpu_variables() {
    # Make sure it has some value
    if [ -z "${CPU_LIMIT}" ]; then
	CPU_LIMIT=1.0
	export CPU_LIMIT
    fi
    # Force it to an integer
    declare -i cpu_limit
    # We really don't have bc in the container
    cpu_limit=$( echo "${CPU_LIMIT}" | cut -d . -f 1)
    # Force it to at least one
    if [ ${cpu_limit} -lt 1 ]; then
       ${cpu_limit} = 1
    fi
    CPU_COUNT=${cpu_limit}
    export CPU_COUNT
    GOTO_NUM_THREADS=${cpu_limit}
    MKL_DOMAIN_NUM_THREADS=${cpu_limit}
    MKL_NUM_THREADS=${cpu_limit}
    MPI_NUM_THREADS=${cpu_limit}
    NUMEXPR_NUM_THREADS=${cpu_limit}
    NUMEXPR_MAX_THREADS=${cpu_limit}
    OMP_NUM_THREADS=${cpu_limit}
    OPENBLAS_NUM_THREADS=${cpu_limit}
    RAYON_NUM_THREADS=${cpu_limit}
    export GOTO_NUM_THREADS MKL_DOMAIN_NUM_THREADS MKL_NUM_THREADS
    export MPI_NUM_THREADS NUMEXPR_NUM_THREADS NUMEXPR_MAX_THREADS
    export OMP_NUM_THREADS OPENBLAS_NUM_THREADS RAYON_NUM_THREADS
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
# Set custom CPU variables
set_cpu_variables
# Set up custom logger
copy_logging_profile
# Make ls colorization better
copy_dircolors
# Retrieve image digest.  Nublado v3: it will be in JUPYTER_IMAGE_SPEC
# already, because we pull with the digest
if echo "${JUPYTER_IMAGE_SPEC}" | grep -q '@sha256:'; then
    IMAGE_DIGEST=$(echo ${JUPYTER_IMAGE_SPEC} \
                   | cut -d '@' -f 2 \
                   | cut -d ':' -f 2)
else
    IMAGE_DIGEST=$(python -c 'import lsst.rsp; print(lsst.rsp.get_digest())')
fi
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
jh_path="${JUPYTERHUB_BASE_URL}hub"
ext_host=$(echo $EXTERNAL_INSTANCE_URL | cut -d '/' -f 3)
if [ -n "${HUB_SERVICE_HOST}" ]; then
    jh_proto=$(echo $JUPYTERHUB_API_URL | cut -d '/' -f -1)
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
FIREFLY_ROUTE=${FIREFLY_ROUTE:-"/firefly/"}
FIREFLY_URL="${EXTERNAL_INSTANCE_URL}${FIREFLY_ROUTE}"
if [ -n "${EXTERNAL_FIREFLY_URL}" ]; then
    FIREFLY_URL=${EXTERNAL_FIREFLY_URL}
fi
FIREFLY_HTML="slate.html"
export FIREFLY_URL FIREFLY_HTML
export JUPYTER_PREFER_ENV_PATH="no"
# Fetch/update magic notebook.  We want this in interactive and noninteractive
#  pods.  We must have ${HOME} mounted but that is the case for both of those
# scenarios.
. /opt/lsst/software/jupyterlab/refreshnb.sh
eups admin clearCache 
if [ -n "${NONINTERACTIVE}" ]; then
    start_noninteractive
    exit 0 # Not reached
else
    # These tasks should only be run if we are an interactive lab rather than
    # a noninteractive lab.
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
     --hub-prefix=${jh_path} \
     --hub-host=${ext_host} \
     --log-level=WARN \
     --ContentsManager.allow_hidden=True \
     --FileContentsManager.hide_globs=[] \
     --KernelSpecManager.ensure_native_kernel=False \
     --QtExporter.enabled=False \
     --PDFExporter.enabled=False \
     --WebPDFExporter.allow_chromium_download=True \
     --ServerApp.shutdown_no_activity_timeout=${NO_ACTIVITY_TIMEOUT} \
     --MappingKernelManager.cull_idle_timeout=${CULL_KERNEL_IDLE_TIMEOUT} \
     --MappingKernelManager.cull_connected=${CULL_KERNEL_CONNECTED} \
     --MappingKernelManager.cull_interval=${CULL_KERNEL_INTERVAL} \
     --MappingKernelManager.default_kernel_name=lsst \
     --TerminalManager.cull_inactive_timeout=${CULL_TERMINAL_INACTIVE_TIMEOUT} \
     --TerminalManager.cull_interval=${CULL_TERMINAL_INTERVAL} \
     --LabApp.check_for_updates_class=jupyterlab.NeverCheckForUpdate"

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
