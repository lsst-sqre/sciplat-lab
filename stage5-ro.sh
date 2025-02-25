#!/bin/sh
set -e

# Set up default user directory layout, which is just a "notebooks" directory.
mkdir -p /etc/skel/notebooks

# We renamed "lsst" to "lsst_lcl" because "lsst" was a real GitHub group
# that people were in, when we were using GH as our auth source.  It still
# seems likely that we may have a legitimate "lsst" group that is not
# the same as the default group for the build user.

if [ -d /home/lsst ]; then
    mv /home/lsst /home/lsst_lcl
fi

# Passwd and group are injected as secrets.  We don't need their shadow
# variants since they will never be used for authentication, and we definitely
# do not need backups of the passwd/group files.  Nor do we need the
# subuid/subgid stuff, since we do not want to delegate user or group
# identities any further.

rm -f /etc/passwd  /etc/shadow  /etc/group  /etc/gshadow \
      /etc/passwd- /etc/shadow- /etc/group- /etc/gshadow- \
      /etc/subuid  /etc/subgid \
      /etc/subuid- /etc/subgid-

# Check out notebooks-at-build-time
# Do a shallow clone (important for the tutorials)
nbdir="/opt/lsst/software/notebooks-at-build-time"
owd=$(pwd)
source ${LOADRSPSTACK}
mkdir -p ${nbdir}
cd ${nbdir}
git clone --depth 1 -b prod "https://github.com/lsst-sqre/system-test"
git clone --depth 1 "https://github.com/lsst/tutorial-notebooks"
cd ${owd}
