#!/bin/bash

ARGS=1         # Script requires 1 arguments.

if [ $# -ne "$ARGS" ]; then
    echo -e "\n USAGE: `basename $0` the script requires one argument - rule file."
    exit 1;
fi

if [ -f regression_config ];then
    . regression_config
else
    echo " \"regression_config \" not found !"
    exit 1;
fi

RULEDIR="${BASEDIR}/rules/"
PCAPS="${BASEDIR}/pcaps/"
RULES="${1}"

for sid in `ls ${PCAPS} |cut -d "." -f1`; do
#    echo $sid
    RULEFILE="${sid}.rules"
    RULEPATH="${RULEDIR}/${RULEFILE}"
#    echo "${RULEPATH}"

    if [ ! -f ${RULEPATH} ]; then
        `grep ${sid} ${RULES} > ${RULEPATH}`
        RETVAL=$?
        if [ ${RETVAL} = "1" ]; then
            echo "${sid} not found"
            `rm ${RULEPATH}`
        fi

        if [ -f ${RULEPATH} ]; then
#            echo "${RULEPATH} exists"
            FLOWBITS=`grep "flowbits:isset" ${RULEPATH} | wc -l`
            if [ ${FLOWBITS} -eq "1" ]; then
                grep "flowbits:set" ${RULES} >> ${RULEPATH}
                grep "flowbits:toggle" ${RULES} >> ${RULEPATH}
                grep "flowbits:unset" ${RULES} >> ${RULEPATH}
            fi

            # uncomment all rules
            sed -i 's/^#*\(.*\)/\1/g' ${RULEPATH}
            sed -i "s/^[[:blank:]]*\(.*\)/\1/g" "${RULEPATH}"
        fi
    fi
done

