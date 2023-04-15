#!/bin/sh
# This will be an interactive system, so we do want man pages after all
# And we have non-US users, so we do not want to force only en_US.utf-8
sed -i -e '/tsflags\=nodocs/d' \
       -e '/override_install_langs\=en_US.utf8/d' /etc/yum.conf
yum clean all
yum install -y epel-release man man-pages
yum repolist
yum -y upgrade
rpm -qa --qf "%{NAME}\n" | xargs yum -y reinstall
# Add some other packages
#  libXScrnSaver ... gtk3 are needed for the chromium installation for
#   JupyterLab WebPDF conversion
#  perl-Digest-MD5 ... file are generally useful utilities
#  ...and finally enough editors to cover most people's habits
yum -y install \
    libXScrnSaver alsa-lib cups-libs at-spi2-atk pango gtk3 \
    perl-Digest-MD5 jq unzip ack screen tmux tree file \
    nano vim-enhanced emacs-nox ed
# Clear build cache
yum clean all

# export RPM list; verdir is an ARG and has already been created.
rpm -qa | sort > ${verdir}/rpmlist.txt
