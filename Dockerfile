FROM python:3.12.7-slim-bookworm AS base-image
USER root
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY scripts/install-base-packages /tmp/build
RUN ./install-base-packages

# Now we have a patched python container.  Add system dependencies.

FROM base-image AS deps-image
COPY scripts/install-dependency-packages /tmp/build
RUN ./install-dependency-packages

# Add other system-level files

# /etc/profile.d parts

RUN mkdir -p /etc/profile.d

COPY profile.d/local01-nbstripjq.sh \
     profile.d/local02-hub.sh \
     profile.d/local03-pythonrc.sh \
     profile.d/local04-path.sh \
     profile.d/local05-term.sh \
     /etc/profile.d/

# /etc/skel

RUN for i in notebooks WORK DATA; do mkdir -p /etc/skel/${i}; done

COPY skel/pythonrc /etc/skel/.pythonrc

# Might want to move these?  Or make them owned by jupyter user?
# But for right now they need to live here as a compatibility layer if
# nothing else.

COPY jupyter_server/jupyter_server_config.json \
     jupyter_server/jupyter_server_config.py \
     /usr/local/etc/jupyter/

COPY scripts/install-system-files /tmp/build
RUN ./install-system-files

# Add our new unprivileged user.

FROM deps-image AS user-image

COPY scripts/make-user /tmp/build
RUN ./make-user

# Give jupyterlab ownership to unprivileged user

RUN mkdir -p /usr/local/share/jupyterlab
RUN chown jovyan:jovyan /usr/local/share/jupyterlab

# Switch to unprivileged user

USER jovyan:jovyan

FROM user-image AS jupyterlab-image

COPY scripts/install-jupyterlab /tmp/build
RUN ./install-jupyterlab

FROM jupyterlab-image AS base-rsp-image

RUN mkdir -p /usr/local/share/jupyterlab/etc
COPY --chown=jovyan:jovyan \
     jupyter_server/jupyter_server_config.json \
     jupyter_server/jupyter_server_config.py

COPY --chown=jovyan:jovyan runtime/runlab \
     /usr/local/share/jupyterlab/

FROM base-rsp-image AS manifests-rsp-image

# Get our manifests.  This has always been really useful for debugging
# "what broke this week?"

COPY scripts/generate-versions /tmp/build
RUN ./generate-versions

FROM manifests-rsp-image AS rsp-image

# This needs to be numeric, since we will remove /etc/passwd and friends
# while we're running.
USER 0:0

# Add startup shim.
COPY scripts/install-compat /tmp/build
RUN  ./install-compat

WORKDIR /

# Clean up.
COPY scripts/cleanup-files /
RUN ./cleanup-files
RUN rm ./cleanup-files

# Back to unprivileged
USER 1000:1000
WORKDIR /tmp

CMD ["/usr/local/share/jupyterlab/runlab"]

ENV  DESCRIPTION="Rubin Science Platform Notebook Aspect"
ENV  SUMMARY="Rubin Science Platform Notebook Aspect"

LABEL description="Rubin Science Platform Notebook Aspect"
