#!/bin/sh
origdir=$(pwd)
# Using a different environment variable allows us to retain backwards
#  compatibility
if [ -n "${AUTO_REPO_SPECS}" ]; then
    urls=${AUTO_REPO_SPECS}
else
    urls=${AUTO_REPO_URLS:="https://github.com/lsst-sqre/notebook-demo"}
fi
urllist=$(echo ${urls} | tr ',' ' ')
# Default branch is only used in the absence of a branch spec in a URL
default_branch=${AUTO_REPO_BRANCH:="prod"}
# We need to have sourced ${LOADRSPSTACK} before we run this.  In the RSP
#  container startup environment, we always will have done so already.
# If LSST_CONDA_ENV_NAME is not set, we have not sourced it...so do.
if [ -z "${LSST_CONDA_ENV_NAME}" ]; then
    source ${LOADRSPSTACK}
fi
for url in ${urllist}; do
    branch=$(echo ${url} | cut -d '@' -f 2)
    # Only use default_branch if branch is not specified in the URL
    if [ "${branch}" == "${url}" ]; then
        branch=${default_branch}
    fi
    repo=$(echo ${url} | cut -d '@' -f 1)
    reponame=$(basename ${repo} .git)
    dirname="${HOME}/notebooks/${reponame}"
    # If dirname doesn't exist, the user gets a read-only copy.  We also
    #  take the opportunity to garbage-collect it, in case the clone has
    #  a whole bunch of removed notebook outputs in it.
    # We will try to do the right thing if it's r/w, but...at your own risk
    if ! [ -d "${dirname}" ]; then
        cd "${HOME}/notebooks" && \
            (git clone --depth 1 ${repo} -b ${branch} >/dev/null 2>&1) && \
            chmod -R ugo-w "${dirname}"
    else
        cd "${dirname}"
        if [ "$(pwd)" != "${dirname}" ]; then
            echo 1>&2 "Could not find repository in ${dirname}"
        else
            dirty=0
            otherbranch=0
            rw=0
            upstream=$(git remote -v | grep origin | grep fetch \
                           | awk '{print $2}')
            repo=$(basename "${dirname}")
            firstfile=$(ls -1 | head -1)
            if [ -n "${firstfile}" ]; then
                if [ -w "${firstfile}" ]; then
                    # We were already read/write...shenanigans
                    rw=1
                fi
            fi
            if [ "${rw}" -eq 0 ]; then
                # Temporarily make branch writeable
                chmod -R u+w "${dirname}"
            fi
            currentbr=$(git rev-parse --abbrev-ref HEAD)
            if [ "${currentbr}" != "${branch}" ]; then
                otherbranch=1
            fi
            # If we have uncommited changes, stash, then we will pop back and
            #  apply after pull
            if ! git diff-files --quiet --ignore-submodules --; then
                ( git stash > /dev/null 2>&1 )
                dirty=1
            fi
            # Do we need to change branches?
            if [ "${otherbranch}" -ne 0 ]; then
                ( git checkout ${branch} > /dev/null 2>&1 )
            fi
            git pull
            if [ "${otherbranch}" -ne 0 ]; then
                ( git checkout ${currentbr} > /dev/null 2>&1 )
            fi
            if [ "${dirty}" -ne 0 ]; then
                ( git stash apply > /dev/null 2>&1 )
            fi
            if [ "${rw}" -ne 0 ] || \
                   [ "${dirty}" -ne 0 ] || \
                   [ "${otherbranch}" -ne 0 ]; then
                # We need to drop the warning in, because the user did not
                # leave it read-only and on the default branch.
                #
                # In short, they are in an unsupported state, and we
                # recommend they delete the directory and get a new one next
                # time they launch a lab.
                jl=/opt/lsst/software/jupyterlab                
                sed -e "s|{{DIR}}|${repo}|" \
                    -e "s|{{BRANCH}}|${branch}|" \
                    -e "s|{{UPSTREAM}}|${upstream}|" \
                    "${jl}/00_WARNING_README.md.template" > \
                    ${dirname}/00_WARNING_README.md
                if [ -f "${jl}/warning-${repo}.md" ]; then
                    cat "${jl}/warning-${repo}.md" >> \
                        ${dirname}/00_WARNING_README.md
                fi
            fi
            if [ "${rw}" -eq 0 ]; then
                # Change it back to read-only
                chmod -R ugo-w "${dirname}"
            fi
        fi
    fi
done
cd "${origdir}" # In case we were sourced and not in a subshell
