#!/bin/bash

PCAPS="../"
RULES="etpro-all.rules"

for sid in `ls ${PCAPS} |cut -d "." -f1`; do
    #echo $sid
    RULEFILE="${sid}.rules"
    RULEPATH="${PCAPS}/${RULEFILE}"

    if [ ! -f ${RULEPATH} ]; then
        `grep ${sid} ${RULES} > ${RULEPATH}`
        RETVAL=$?
        if [ ${RETVAL} = "1" ]; then
            echo "${sid} not found"
            `rm ${RULEPATH}`
        fi

        if [ -f ${RULEPATH} ]; then
            FLOWBITS=`grep "flowbits:isset" ${RULEPATH} | wc -l`
            if [ ${FLOWBITS} -eq "1" ]; then
                grep "flowbits:set" ${RULES} >> ${RULEPATH}
            fi
        fi
    fi
done

# uncomment all rules
sed -i "s/^#${1}/${1}/g" ${PCAPS}/*.rules
sed -i "s/^#${1}/${1}/g" ${PCAPS}/*.rules
sed -i "s/^[[:blank:]]${1}/${1}/g" ${PCAPS}/*.rules
sed -i "s/^[[:blank:]]${1}/${1}/g" ${PCAPS}/*.rules
