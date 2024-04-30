#!/bin/sh

site_recommendation () {
    cat << EOF

To create a Rubin Observatory environment in a terminal session and set up
an appropriate set of packages:

EOF

    case $RSP_SITE_TYPE in
        telescope | staff)
            echo "        setup lsst_sitcom"
	    echo ""
            ;;
        *)
            echo "        setup lsst_distrib"
	    echo ""
            ;;
    esac
}

case "$-" in
    *i*)
        # OK, we're interactive.
        #  Are we a login shell?
        if shopt -q login_shell; then
            # Yes.  Display the notice(s)
            if [ -e "/usr/local/etc/rsp_notice" ]; then
                cat /usr/local/etc/rsp_notice
                site_recommendation
            fi
            msgdir="/opt/lsst/software/jupyterlab/messages.d"
            if [ -e  ${msgdir} ]; then
                any=$(ls ${msgdir})
                if [ -n "${any}" ]; then
                    cat ${msgdir}/*
                fi
            fi
        fi
        ;;
    *)
        ;;
esac
