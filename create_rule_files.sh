#!/bin/bash

RULEDIR="/home/victor/suriqa/rules/"
PCAPS="/home/victor/suriqa/pcaps/"
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

