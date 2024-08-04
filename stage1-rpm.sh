#!/bin/sh
# It doesn't look like the Alma build is stripping man pages or
# enforcing en_us.utf-8 anymore.
dnf clean all
dnf install -y epel-release man man-pages
# Enable the CRB repository
/usr/bin/crb enable
dnf repolist
dnf -y upgrade
# Add some other packages
#  libXScrnSaver ... gtk3 are needed for the chromium installation for
#   JupyterLab WebPDF conversion
#  perl-Digest-MD5 ... file are generally useful utilities
#  glibc-all-langpacks gives us support for many locales
#  ...and finally enough editors to cover most people's habits
dnf -y install \
    libXScrnSaver alsa-lib cups-libs at-spi2-atk pango gtk3 \
    perl-Digest-MD5 jq unzip ack screen tmux tree file \
    glibc-all-langpacks \
    nano vim-enhanced emacs-nox ed
# Clear build cache
dnf clean all

# export RPM list; verdir is an ARG and has already been created.
rpm -qa | sort > ${verdir}/rpmlist.txt
