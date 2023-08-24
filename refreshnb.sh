#!/bin/sh

set -e

timeout=30  # Not forever, but long enough to account for some network issues

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

# We need to have sourced ${LOADRSPSTACK} before we run this, because that
#  is where git comes from.
# In the RSP container startup environment, we always will have done so,
#  but if LSST_CONDA_ENV_NAME is not set, we have not sourced it...so do.
if [ -z "${LSST_CONDA_ENV_NAME}" ]; then
    source ${LOADRSPSTACK}
fi

# Loop over our automatically-pulled repositories.
for url in ${urllist}; do
    branch=$(echo ${url} | cut -d '@' -f 2)
    # Only use default_branch if branch is not specified in the URL
    if [ "${branch}" = "${url}" ]; then
        branch=${default_branch}
    fi
    repo=$(echo ${url} | cut -d '@' -f 1)
    reponame=$(basename ${repo} .git)
    dirname="${HOME}/notebooks/${reponame}"

    if [ -d "${dirname}" ]; then
        if [ -w "${dirname}" ]; then
            # The repository is writeable.  So we relocate it, and
            # create/update the relocation readme file in the parent dir.
            human_now=$(date)
            now=$(date +%Y%m%d%H%M%S)
            new="${dirname}-${now}"
            mv "${dirname}" "${new}"
            rd="${HOME}/notebooks/00_README_RELOCATION.md"
            if ! [ -f "${rd}" ]; then
                # Write the file header if the file didn't exist.
                echo "## Directory relocation" > ${rd}
                echo "" >> ${rd}
                echo -n "The following were read-write, and have" >> ${rd}
                echo " been relocated as follows:" >> ${rd}
                echo "" >> ${rd}
            fi
            echo "- ${human_now}: ${dirname} -> ${new}" >> ${rd}
        else
            # We might get to go home early.  If the repository exists, and it
            # is not writeable, see if it has the same last commit as the
            # remote.
            #
            # We're not going to protect against the case where someone
            # makes it writeable, changes something, and then changes it
            # back to read-only, but, come on, if you do that, you deserve
            # what you get.
            #
            # We need to be sitting in the repo for git config to work.
            cd "${dirname}"
            remote=$(git config --get remote.origin.url)
            # Set up our comparison to see whether the branch is stale.
            branch_re="\\srefs/heads/${branch}\$"
            remote_sha=$(timeout $timeout git ls-remote ${remote} | \
                             grep "${branch_re}" | \
                             awk '{print $1}')
            local_sha=$(git rev-parse HEAD)
            # Go back to where we were now that we have the commit SHA of
            # both remote and local.
            cd "${origdir}"
            if [ "${local_sha}" = "${remote_sha}" ]; then
                # We're fine.  Don't do anything.  Skip ahead.
                continue
            fi
            # It's not up-to-date, so make it read-write so we can remove it.
            chmod -R u+w "${dirname}"
            # And remove it.
            rm -rf "${dirname}"
        fi
    fi
    # If we got here, within the loop iteration, either the directory
    # didn't exist to start with, we moved it aside because it was
    # writeable, or we removed it because it was stale.
    timeout ${timeout} \
            git clone --depth 1 ${repo} -b ${branch} "${dirname}" \
            >/dev/null 2>&1
    # Finally, make it read-only
    chmod -R ugo-w "${dirname}"
done
cd "${origdir}" # In case we were sourced and not in a subshell
