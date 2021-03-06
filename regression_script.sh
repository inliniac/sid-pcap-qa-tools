#!/bin/bash
# the script takes one directory as an argument
# explantion of exactly what the script does please see at the end

#set -x

input=$1
output=$2
config=$3
ARGS=2         # Script requires 2 arguments.
#E_BADARGS=85   # Wrong number of arguments passed to script.
ERR_CODE=0     #defaulting to success return to the OS

echo -e "\n Supplied directory is:  $input \n";

if [ $# -le "$ARGS" ]; then
    echo -e "\n USAGE: `basename $0` the script requires two arguments - directory, name."
    exit 1;
fi
#above check if valid number of arguments are passed to the script - should be 1 (directory location)

if [ ! -d "$input" ]; then
    # Control will enter here if DIRECTORY doesn't exist
    echo "The supplied directory does not exist or the name is wrong !"
    exit 1;
fi

OPTIONS=""

#below we check if the configurational file exists and load the $SURICATA and $CONFIG values from there
if [ ! -z ${config} ]; then
    source ${config}
elif [ -f ${input}/sid-pcap-qa-tools/regression_config ]; then
	. ${input}/sid-pcap-qa-tools/regression_config
else
    echo " \"regression_config \" not found !"
    exit 1;
fi

SUCCESS="0"
FAILURE="0"
SKIPPED="0"
BLACKLISTED="0"
KNOWNBUGS="0"

BIN=${SURICATA}
if [ -f "${input}/install/${output}/bin/suricata" ]; then
    BIN="${input}/install/${output}/bin/suricata"
fi
echo " Binary $BIN"
echo " Build info:"
echo
$BIN --build-info
echo

KB="${input}/knownbugs.txt"
BL="${input}/blacklist.txt"
PCAPS="${input}/pcaps/"
RULES="${input}/rules/"
YAMLS="${input}/yamls/"
LOGS="${output}"

if [ "${LOGS}" = "" ]; then
    echo "FATAL LOGS not set"
    exit 1
fi
if [ -d ${LOGS} ]; then
    if [[ $EUID -eq 0 ]]; then
        echo "cowardly refusing to rm things as root"
    else
        rm -r ${LOGS}
        mkdir -p ${LOGS}
    fi
else
    mkdir -p ${LOGS}
fi

CWD=`pwd`
#cd ${LOGS}

for pcap_file in  $( dir ${PCAPS} -1 |grep .pcap$ ); do
    pcap_name="$(echo "$pcap_file" |awk -F "." ' { print $1 } ')"

    rule_id=${pcap_name}

    if [ ! -z $PCAP_FILTER ]; then
        if test $(echo $pcap_name | grep ${PCAP_FILTER} | wc -l) = "0"; then
            let SKIPPED=$SKIPPED+1;
            continue
        fi
    fi

    if [ ! -f "${RULES}/$rule_id.rules" ]; then
        #echo "File \"$rule_id.rules\" corresponding to $pcap_file not found! "
        let ERR_CODE=$ERR_CODE+1;
        #exit $ERR_CODE ;

        let SKIPPED=$SKIPPED+1;
        continue
    fi

    SHA256=`sha256sum ${PCAPS}/$pcap_file|cut -f 1 -d " "`
    BLLINE="${SHA256} ${rule_id}"
    #echo "$BLLINE"
    if [ -f ${BL} ]; then
        if test `grep "${BLLINE}" ${BL}|wc -l` = "1"; then
            echo "BLACKLISTED"
            let BLACKLISTED=$BLACKLISTED+1;
            continue
        fi
    fi
    if [ -f ${KB} ]; then
        if test `grep "${BLLINE}" ${KB}|wc -l` = "1"; then
            echo "KNOWNBUG"
            let KNOWNBUGS=$KNOWNBUGS+1;
            continue
        fi
    fi

    TMP_DIR_NAME="${LOGS}/suriqa-${rule_id}.XXXXXXXX"
    TMP_LOG=`mktemp -d ${TMP_DIR_NAME}` #creating a tmp log name
    `mkdir $TMP_LOG/files` # making a "files" directory, just in case if magic files are enabled in yaml, so that we do not stop suri from execution.
    `mkdir $TMP_LOG/certs` # making a "files" directory, just in case if magic files are enabled in yaml, so that we do not stop suri from execution.

    # the above if statement checks for a corresponding rules file to the pcap supplied

    MYCONFIG="${YAMLS}/${rule_id}.yaml"
    if [ ! -f ${MYCONFIG} ]; then
        MYCONFIG=${CONFIG}
    fi

    PACKETS=`capinfos -c -T ${PCAPS}/${pcap_file} |grep ${pcap_file}|awk '{print $2}'`
    #echo "PACKETS ${PACKETS}"

    CMD="$BIN -c ${MYCONFIG} --runmode=single -S ${RULES}/${rule_id}.rules -r ${PCAPS}/${pcap_file} -l $TMP_LOG/ ${OPTIONS} -v"
    $CMD &> "$TMP_LOG/output"
    RETVAL=$?
    #echo "RETVAL $RETVAL"
    SECS=`grep "elapsed" "$TMP_LOG/output"|awk -F'time elapsed ' '{print $2}'|cut -f 1 -d's'`

    PPS="$(bc <<< "$PACKETS / $SECS")"
    #echo "SECS $SECS PPS $PPS"
    if [ $(bc <<< "$SECS >= 2") -eq 1 ] && [ $PPS -lt 5000 ]; then
        echo "SLOW PCAP: $PPS pps, $SECS time"
    fi


    if [ $(bc <<< "$SECS > 2") -eq 1 ]; then
        echo "LONG! $PACKETS packets $SECS secs $PPS pps ${RULES}/${rule_id}.rules ${PCAPS}/${pcap_file}"
    fi
    #run Suricata

    number_of_alerts="$(cat $TMP_LOG/fast.log |grep \:${rule_id}: |wc -l)"
    #count the number of alerts with that particular rules files SID

    if [ "$number_of_alerts" -eq "0" ] || [ "$RETVAL" -ne 0 ]; then
        echo $CMD > $TMP_LOG/command.log
        echo $rule_id ": FAILED, see $TMP_LOG, rulefile: $rule_id.rules, pcap file $pcap_file, Expected alerts, got $number_of_alerts. RETVAL $RETVAL"
        let FAILURE=$FAILURE+1 ;
#        cat $TMP_LOG/command.log
#        cat $TMP_LOG/output

        # store the pcap and rule file
        cp "${PCAPS}/${pcap_file}" "$input/fails/"
        cp "${RULES}/${rule_id}.rules" "$input/fails/"
        if [ -f "${YAMLS}/${rule_id}.yaml" ]; then
            cp "${YAMLS}/${rule_id}.yaml" "$input/fails/"
        fi

    else
        echo $rule_id ": OK"
        let SUCCESS=$SUCCESS+1;
        ` rm -r $TMP_LOG `
        #above removing the temp log directory ONLY if the test has SUCCEEDED
    fi
done

echo; echo "SUMMARY:"
echo "-----------"
echo "SUCCESS: " $SUCCESS;
echo "FAILURE: " $FAILURE;
echo "SKIPPED: " $SKIPPED;
echo "BLACKLISTED: " $BLACKLISTED;
echo "KNOWNBUGS: " $KNOWNBUGS;
cd $CWD

 [[ $FAILURE -eq "0" ]] && exit 0 || exit 1
#the upper line - if failures are 0 it returns success, otherwise error to the  OS




# THIS IS WHAT THE SCRIPT DOES !!!!!!!!!!!!
# If you have time, can you write me a regression testing script? I'd like
# the script to be simple.
#
# It takes in 2 arguments: a pcap and a rule file. The name of the pcap
# will be in this format:
#
# 2002031-001-sandnet-public-tp-01.pcap
#
# meaning:
#
# 2002031 - rule id (sid)
# 001 - pcap id (for having multiple pcaps for a sid)
# sandnet - pcap source
# public - whether or not the pcap can be shared
# tp - true positive (fp for false positive)
# 01 - number of alerts we should see for the sid
#
# The rule file should be in the this format:
#
# 2002031.rules
#
# The goal is simple. The script should run the pcap against the rules and
# check if the number of alerts is correct. If it isn't, display an
# error/warning.
