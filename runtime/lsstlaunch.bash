#!/bin/bash
CONFIG_FILE=$1

fallback () {
    # /opt/lsst/sal only exists in SAL builds of the stack
    source /opt/lsst/software/stack/loadLSST.bash
    if [ -d /opt/lsst/sal ]; then
	setup lsst_sitcom  # RFC-992
    else
        setup lsst_distrib
    fi
    setup display_firefly
    LSST_KAFKA_SECURITY_USERNAME=$(cat ${LSST_KAFKA_PASSFILE} | \
				       cut -d: -f1)
    LSST_KAFKA_SECURITY_PASSWORD=$(cat ${LSST_KAFKA_PASSFILE} | \
				       cut -d: -f2)
    export LSST_KAFKA_SECURITY_USERNAME LSST_KAFKA_SECURITY_PASSWORD
}

if [ -z "${RSP_SITE_TYPE}" ]; then
   fallback  # Preserve backwards compatibility for a while
else
    case ${RSP_SITE_TYPE} in
	telescope)
            source /opt/lsst/software/stack/loadLSST.bash	    
	    setup lsst_sitcom
	    setup display_firefly
	    LSST_KAFKA_SECURITY_USERNAME=$(cat ${LSST_KAFKA_PASSFILE} | \
					       cut -d: -f1)
	    LSST_KAFKA_SECURITY_PASSWORD=$(cat ${LSST_KAFKA_PASSFILE} | \
					       cut -d: -f2)
	    export LSST_KAFKA_SECURITY_USERNAME LSST_KAFKA_SECURITY_PASSWORD
	    ;;
	staff)
            source /opt/lsst/software/stack/loadLSST.bash
	    setup lsst_sitcom
	    setup display_firefly
	    ;;
	*)  # Should be "science", and let's make that the default case.
            source /opt/lsst/software/stack/loadLSST.bash
	    setup lsst_distrib
	    setup display_firefly
	    ;;
    esac
fi

# Source user_setups if it's there
if [ -e ${HOME}/notebooks/.user_setups ]; then
    source ${HOME}/notebooks/.user_setups
fi
# And now transfer control over to Python
exec python3 -m ipykernel -f ${CONFIG_FILE}
