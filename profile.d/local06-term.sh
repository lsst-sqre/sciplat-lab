#!/bin/sh
if [ "${TERM}" == "xterm" ]; then
    TERM="xterm-color"
fi
export TERM

eval $(dircolors -b /etc/dircolors.ansi-universal)
alias ls="ls --color=auto"
