#!/bin/sh
# OS-level packages that are not packaged by either RPM or Conda
mkdir -p ${srcdir}/thirdparty

# Install Hub
cd /tmp
V="2.14.2"
FN="hub-linux-amd64-${V}"
F="${FN}.tgz"
URL="https://github.com/github/hub/releases/download/v${V}/${F}"
cmd="curl -L ${URL} -o ${F}"
${cmd}
tar xpfz ${F}
install -m 0755 ${FN}/bin/hub /usr/bin
rm -rf ${F} ${FN}

# This is for Fritz, and my nefarious plan to make the "te" in "Jupyter"
#  TECO
# We switched from TECOC to Paul Koning's Python implementation because it
#  simplifies installation a bit.  I doubt anyone is going to complain.
cd ${srcdir}/thirdparty
source ${LOADRSPSTACK} # To get git
git clone https://github.com/pkoning2/pyteco.git
cd pyteco
install -m 0755 teco.py /usr/local/bin/teco

# The default terminal colors look bad in light mode.
cd ${srcdir}/thirdparty
git clone https://github.com/seebi/dircolors-solarized.git
cd dircolors-solarized
cp dircolors* /etc

# Clear our caches
rm -rf /tmp/* /tmp/.[0-z]*
