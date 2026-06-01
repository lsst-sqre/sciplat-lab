ARG input
FROM $input AS base-image
USER 0:0
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

# Add other system-level files

# An /etc/passwd and /etc/group

COPY static/etc/passwd /etc/passwd
COPY static/etc/group  /etc/group
RUN grpconv && pwconv

COPY scripts/install-system-packages /tmp/build
# profile.d now means we always start in ${HOME}.
RUN cd /tmp/build && ./install-system-packages

# /etc/profile.d parts

RUN mkdir -p /etc/profile.d

COPY static/etc/profile.d/local07-showrspnotice.sh \
     static/etc/profile.d/local08-setupstack.sh \
     /etc/profile.d/

# /etc/skel
# Coordinate dropping or lowercasing WORK and DATA with CST
RUN for i in WORK DATA notebooks ; do \
        mkdir -p /etc/skel/${i} ; \
    done

COPY static/etc/skel/gitconfig /etc/skel/.gitconfig
COPY static/etc/skel/git-credentials /etc/skel/.git-credentials
COPY static/etc/skel/user_setups /etc/skel/notebooks/.user_setups

# This goes onto a Jupyter path, which is *not* /etc/nublado.
COPY static/etc/nublado/lsst_kernel.json \
       /usr/local/share/jupyter/kernels/lsst/kernel.json

# Add the DM stack.

FROM base-image AS base-stack-image
ARG tag

COPY scripts/install-dm-stack /tmp/build
RUN cd /tmp/build && ./install-dm-stack ${tag}

COPY static/etc/nublado/rsp_notice static/etc/nublado/20-logging.py \
     static/etc/nublado/lsst_kernel.json static/etc/nublado/lsstlaunch.bash \
     /etc/nublado

COPY scripts/install-rsp-user /tmp/build
COPY scripts/extract-rubin-env-rsp.py /tmp/build
RUN cd /tmp/build && ./install-rsp-user
RUN mkdir -p /usr/local/etc/jupyter/labconfig
COPY scripts/modify-settings.py /tmp/build
RUN cd /tmp/build && python3 ./modify-settings.py

FROM base-stack-image AS compat-rsp-image

# Add compatibility layer to allow for transition from old to new
# paths.

COPY scripts/install-compat /tmp/build
RUN cd /tmp/build && ./install-compat

FROM compat-rsp-image AS manifests-rsp-image

# Get our manifests.  This has always been really useful for debugging
# "what broke this week?"

COPY scripts/generate-versions /tmp/build
RUN cd /tmp/build && ./generate-versions

FROM manifests-rsp-image AS rsp-image
ARG version

# Clean up.
# This needs to be numeric, since we will remove /etc/passwd and friends
# while we're running.
USER 0:0
WORKDIR /

COPY scripts/cleanup-files /
RUN cd / && ./cleanup-files && rm ./cleanup-files

# Run by default as an unprivileged user.  In real life, the Nublado
# controller will set this correctly.  The default is conventionally
# nobody:nogroup.
USER 65534:65534
WORKDIR /tmp

# This command is provided by the base container.
CMD ["/etc/nublado/runlab"]

# Overwrite Base Container definitions with more-accurate-for-us ones
ENV  DESCRIPTION="Rubin Science Platform Notebook Aspect"
ENV  SUMMARY="Rubin Science Platform Notebook Aspect"

LABEL description="Rubin Science Platform Notebook Aspect: $version" \
       name="sciplat-lab:$version" \
       version="$version"
