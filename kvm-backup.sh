#!/bin/bash
# This script is based on:
# https://nixlab.org/blog/backup-kvm-virtual-machines
# https://www.ludovicocaldara.net/dba/bash-tips-4-use-logging-levels/
# https://borgbackup.readthedocs.io/en/1.1.16/quickstart.html
#
# The VM you want to backup has to support snapshots (qcow2)

### Usage
# When run without parameters, the script will backup all VM's that are not
# in the EXCLUDE_LIST
# when run with a VM name as the first command line argument, only that VM
# will be backed up

### SETTINGS
# Backup dir
BACKUP_DIR=/storage/vmbackup
# VM's to exclude. Array with names as given by 'virsh list'. Example:
#EXCLUDE_LIST=("openwrt" "archlinux-2")
EXCLUDE_LIST=()
# Skip VM's that have been shut down
SKIP_SHUT_OFF=true

### Borg settings
# Borg passphrase. Setting this here, so you won't be asked for your repository passphrase.
# Not needed if BORG_ENCRYPTION_METHOD=none
# Change this to something else
export BORG_PASSPHRASE='J5BX8F9cUNpPvfhwKXc3kqT3NPFaguzF'
# Borg encryption to be used. Location of the key file depends on the method used.
# See: https://borgbackup.readthedocs.io/en/stable/usage/init.html for details.
BORG_ENCRYPTION_METHOD="repokey-blake2"
# Backups to keep, see: https://borgbackup.readthedocs.io/en/stable/usage/prune.html
#PRUNE_KEEP="--keep-daily 7 --keep-weekly 4 --keep-monthly 12"
PRUNE_KEEP="--keep-daily 7 --keep-weekly 4 --keep-monthly 6"
# Compression: Algorithm,level
COMP='zstd,6'

### Logging settings
# Path to a single logfile, all logs will be appended to that file.
# Leave empty and set LOGDIR to log to sepparate files for each script run.
SINGLE_LOGFILE="/var/log/kvmbackup.log"
# Dir to log to, this is ignored when SINGLE_LOGFILE is set
LOGDIR=/var/log
# Log verbosity. 4 is normal output (just virsh and borg program output
# + warnings, errors and notify), 6 is debug
LOG_VERBOSITY=4
# Print output to screen or not
STDOUT_LOG=true

# Define a series of variables as shortcuts for color escape codes
colblk='\033[0;30m'  # Black - Regular
colred='\033[0;31m'  # Red
colgrn='\033[0;32m'  # Green
colylw='\033[0;33m'  # Yellow
colblu='\033[0;34m'  # Blue
colpur='\033[0;35m'  # Purple
colcyn='\033[0;36m'  # Cyan
colwht='\033[0;37m'  # White
colbblk='\033[1;30m' # Black - Bold
colbred='\033[1;31m' # Red
colbgrn='\033[1;32m' # Green
colbylw='\033[1;33m' # Yellow
colbblu='\033[1;34m' # Blue
colbpur='\033[1;35m' # Purple
colbcyn='\033[1;36m' # Cyan
colbwht='\033[1;37m' # White
colublk='\033[4;30m' # Black - Underline
colured='\033[4;31m' # Red
colugrn='\033[4;32m' # Green
coluylw='\033[4;33m' # Yellow
colublu='\033[4;34m' # Blue
colupur='\033[4;35m' # Purple
colucyn='\033[4;36m' # Cyan
coluwht='\033[4;37m' # White
colbgblk='\033[40m'  # Black - Background
colbgred='\033[41m'  # Red
colbggrn='\033[42m'  # Green
colbgylw='\033[43m'  # Yellow
colbgblu='\033[44m'  # Blue
colbgpur='\033[45m'  # Purple
colbgcyn='\033[46m'  # Cyan
colbgwht='\033[47m'  # White
colrst='\033[0m'     # Text Reset

### LOG_VERBOSITY levels
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
ntf_lvl=4
inf_lvl=5
dbg_lvl=6

## esilent prints output even in silent mode
function esilent() { verb_lvl=$silent_lvl elog "$@"; }
function enotify() { verb_lvl=$ntf_lvl elog "$@"; }
function eok() { verb_lvl=$ntf_lvl elog "SUCCESS - $@"; }
function ewarn() { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@"; }
function einfo() { verb_lvl=$inf_lvl elog "${colwht}INFO${colrst} ---- $@"; }
function edebug() { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@"; }
function eerror() { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@"; }
function ecrit() { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@"; }
function edumpvar() { for var in $@; do edebug "$var=${!var}"; done; }
function elog() {
    if [ $LOG_VERBOSITY -ge $verb_lvl ]; then
        datestring=$(date +"%Y-%m-%d %H:%M:%S")
        echo -e "$datestring - $@"
    fi
}

function Log_Open() {
    if [ -z "${SINGLE_LOGFILE}" ]; then
        FULLLOGDIR=$LOGDIR/${SCRIPT_BASE}
        LOGFILE=${LOGDIR}/${SCRIPT_BASE}/${SCRIPT_BASE}_${DATETIME}.log
    else
        FULLLOGDIR=$(dirname ${SINGLE_LOGFILE})
        LOGFILE=${SINGLE_LOGFILE}
    fi
    [[ -d ${FULLLOGDIR} ]] || mkdir -p ${FULLLOGDIR}
    exec 3>&1
    if $STDOUT_LOG; then
        Pipe=${FULLLOGDIR}/${SCRIPT_BASE}_${DATETIME}.pipe
        mkfifo -m 700 $Pipe
        tee -a ${LOGFILE} <$Pipe >&3 &
        teepid=$!
        exec 1>$Pipe
        PIPE_OPENED=1
    else
        exec 1>>${LOGFILE} 2>&1
    fi
    #    esilent "---------- Logging to $LOGFILE ----------"                       # (*)
    #    [ $SUDO_USER ] && enotify "Sudo user: $SUDO_USER" #(*)
}

function Log_Close() {
    if [ ${PIPE_OPENED} ]; then
        exec 1<&3
        if $STDOUT_LOG; then
            sleep 0.2
            ps --pid $teepid >/dev/null
            if [ $? -eq 0 ]; then
                # a wait $teepid whould be better but some
                # commands leave file descriptors open
                sleep 1
                kill $teepid
            fi
            rm $Pipe
            unset PIPE_OPENED
        fi
    fi
}

function backup {
    edebug "Start of borg backup function"
    BORG_REPO=$BACKUP_DIR/"${ACTIVEVM}"
    einfo "Borg repository: ${BORG_REPO}"

    if [ ! -d "$BORG_REPO" ]; then
        einfo "Initializing borg backup for ${DIR} at ${BORG_REPO}"
        edebug "borg init --encryption ${BORG_ENCRYPTION_METHOD} ${BORG_REPO}"
        borg init --encryption ${BORG_ENCRYPTION_METHOD} ${BORG_REPO}
    fi

    trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

    einfo "Starting borg backup for ${ACTIVEVM}"
    edebug "borg create --stats --show-rc --compression ${COMP} ${BORG_REPO}::${ACTIVEVM}'-{now}' ${DISK_PATH[*]} ${XMLFILE} 2>&1"
    borg create --stats --show-rc --compression ${COMP} ${BORG_REPO}::"${ACTIVEVM}"'-{now}' ${DISK_PATH[*]} "${XMLFILE}" 2>&1
    backup_exit=$?

    enotify "Pruning borg repository for ${ACTIVEVM}"
    edebug "borg prune --list --prefix ${ACTIVEVM}'-' --show-rc ${PRUNE_KEEP} $BORG_REPO 2>&1"
    borg prune --list --prefix "${ACTIVEVM}"'-' --show-rc ${PRUNE_KEEP} $BORG_REPO 2>&1
    prune_exit=$?

    # use highest exit code as global exit code
    global_exit=$((backup_exit > prune_exit ? backup_exit : prune_exit))

    if [ ${global_exit} -eq 1 ]; then
        ewarn "Backup and/or Prune finished with a warning for ${ACTIVEVM}"
    fi

    if [ ${global_exit} -gt 1 ]; then
        eerror "Backup and/or Prune finished with an error for ${ACTIVEVM}"
    fi
    edebug "End of borg backup function"
}

# write log
Log_Open

# Check if a previous process is still running
SCRIPT=$(basename $0)
edebug "Check if there is another instance of script '${SCRIPT}' running"
for pid in $(pidof -x ${SCRIPT}); do
    if [ $pid != $$ ]; then
        eerror "${SCRIPT} : Process is already running with PID $pid\n"
        exit 1
    fi
done


VM_LIST_RUNNING=$(virsh list --all | grep -E 'running' | awk '{print $2}')
VM_LIST_OFF=$(virsh list --all | grep -E 'shut off' | awk '{print $2}')
HOSTNAME=$(uname -n)
DATE=$(date +"%Y%m%d")
DATETIME=$(date +"%Y%m%d_%H%M%S")
SCRIPT_BASE=$(basename $0 .sh)

pattern="\b$1\b"
if [[ "${VM_LIST_RUNNING[*]}" =~ $pattern ]] || [[ "${VM_LIST_OFF[*]}" =~ $pattern ]]; then
    if [ "$1" != "" ]; then
        # Command line input exists in vmlist
        VM_LIST=$1
    else
        esilent "--------- START BACKUP OF HOST: ${HOSTNAME} ---------"
        if $SKIP_SHUT_OFF; then
            VM_LIST=${VM_LIST_RUNNING}
        else
            VM_LIST=${VM_LIST_OFF}
        fi
    fi
else
    eerror "$1 is not valid VM\n"
    exit 1
fi

for ACTIVEVM in $VM_LIST; do
    # Check if the VM is in the exclude list, or if it has been set throuth the command line
    if [[ ! ${EXCLUDE_LIST[*]} =~ ([[:space:]]|^)"${ACTIVEVM}"([[:space:]]|$) ]] || [[ "${ACTIVEVM}" == "$1" ]]; then
        pat="\b${ACTIVEVM}\b"
        if [[ "${VM_LIST_OFF[*]}" =~ $pat ]]; then
            VM_IS_ON=false
        else
            VM_IS_ON=true
        fi
        # add vm disk names to array
        edebug "Find disks for ${ACTIVEVM}"
        edebug "virsh domblklist "${ACTIVEVM}" | grep -e vd -e sd | grep -e '/' | awk '{print \$1}'"
        DISK_ARR=($(virsh domblklist "${ACTIVEVM}" | grep -e '/' | awk '{print $1}'))
        # list vm disk names
        edebug "Get VM disk names"
        edebug "virsh domblklist "${ACTIVEVM}" | grep -e vd -e sd | grep -e '/' | awk '{print \$1}'"
        DISK_NAMES=($(virsh domblklist "${ACTIVEVM}" | grep -e vd -e sd | grep -e '/' | awk '{print $1}'))
        # list vm disk paths
        edebug "Get VM disk paths"
        edebug "virsh domblklist "${ACTIVEVM}" | grep -e vd -e sd | grep -e '/' | awk '{print \$2}'"
        DISK_PATH=($(virsh domblklist "${ACTIVEVM}" | grep -e '/' | awk '{print $2}'))

        DO_BACKUP=true
        if $VM_IS_ON; then
            for DISK in ${DISK_PATH[*]}; do
                einfo "Disk path: ${DISK}"
                # Get volume type
                edebug "virsh vol-dumpxml --vol ${DISK} 2>/dev/null | grep -e '<volume' | awk -F \"[']\" '{print \$2}'"
                VOLUME_TYPE=($(virsh vol-dumpxml --vol ${DISK} 2>/dev/null | grep -e '<volume' | awk -F "[']" '{print $2}'; exit ${PIPESTATUS[0]}))
                if [ $? -eq 0 ]; then
                    edebug "Volume type: ${VOLUME_TYPE}"
                    # Check disk type
                    edebug "virsh vol-dumpxml --vol ${DISK} | grep format | awk -F \"[']\" '{print \$2}'"
                    DISK_TYPE=($(virsh vol-dumpxml --vol ${DISK} | grep format | awk -F "[']" '{print $2}'))
                    einfo "Disk type: ${DISK_TYPE}"
                else
                    eerror "Wrong disk type: ${DISK} ABORT!"
                    DO_BACKUP=false
                fi
            done
        fi

        if $DO_BACKUP; then
            esilent "--------- START BACKUP OF VM: ${ACTIVEVM} ---------"
            # create directories
            einfo "Create dir: $BACKUP_DIR/tmp-ext-snap/${ACTIVEVM}"
            mkdir -p $BACKUP_DIR/tmp-ext-snap/"${ACTIVEVM}"
            einfo "Create dir: $BACKUP_DIR/config/${ACTIVEVM}"
            mkdir -p $BACKUP_DIR/config/"${ACTIVEVM}"

            ### VM CONFIG BACKUP
            einfo "Start XML dump of: ${ACTIVEVM}"
            XMLFILE=$BACKUP_DIR/config/"${ACTIVEVM}"/"${ACTIVEVM}"-"$DATETIME".xml
            einfo "Dump to: ${XMLFILE}"
            edebug "virsh dumpxml --migratable ${ACTIVEVM} >${XMLFILE}"
            virsh dumpxml --migratable "${ACTIVEVM}" >"${XMLFILE}"

            if $VM_IS_ON; then
                ### CREATE TEMPORARY EXTERNAL SNAPSHOT
                einfo "Create temporary external VM snapshot of: ${ACTIVEVM}"
                for DISK_ARR_ITEM in ${!DISK_ARR[*]}; do
                    edebug "Create diskspec argument for ${DISK_ARR[$DISK_ARR_ITEM]}"
                    DISKSPEC_ARR+=("--diskspec ${DISK_ARR[$DISK_ARR_ITEM]},file=$BACKUP_DIR/tmp-ext-snap/${ACTIVEVM}/snapshot-"${DISK_ARR[$DISK_ARR_ITEM]}"-$DATETIME.qcow2,snapshot=external")
                done
                edebug "virsh snapshot-create-as --domain ${ACTIVEVM} tmp-ext-snap-$DATETIME ${DISKSPEC_ARR[*]} --disk-only --atomic"
                virsh snapshot-create-as --domain "${ACTIVEVM}" tmp-ext-snap-"$DATETIME" ${DISKSPEC_ARR[*]} --disk-only --atomic
                # empty array
                unset DISKSPEC_ARR
            fi

            ### Borg backup of disk(s)
            einfo "Create borg backup of: ${ACTIVEVM} [${DISK_ARR[@]}]"
            backup

            ### COMMIT SNAPSHOT
            if $VM_IS_ON; then
                for DISK_NAMES_ITEM in ${DISK_NAMES[*]}; do
                    # get path of snapshot
                    edebug "Get snapshot path for ${DISK_NAMES_ITEM}"
                    edebug "virsh domblklist "${ACTIVEVM}" | grep "$DISK_NAMES_ITEM" | awk '{print \$2}'"
                    SNAP_PATH=$(virsh domblklist "${ACTIVEVM}" | grep "$DISK_NAMES_ITEM" | awk '{print $2}')
                    einfo "Commit snapshot: ${ACTIVEVM} [$SNAP_PATH]"
                    # commit snapshot
                    edebug "virsh blockcommit ${ACTIVEVM} $DISK_NAMES_ITEM --active --pivot"
                    virsh blockcommit "${ACTIVEVM}" "$DISK_NAMES_ITEM" --active --pivot
                done

                ### DELETE TEMPORARY EXTERNAL SNAPSHOTS (VM)
                edebug "virsh snapshot-list ${ACTIVEVM} | grep tmp-ext-snap | awk '{print \$1}'"
                SNAPSHOT_LIST=($(virsh snapshot-list "${ACTIVEVM}" | grep tmp-ext-snap | awk '{print $1}'))
                einfo "Delete temporary external snapshot (vm) of: ${ACTIVEVM} [$SNAPSHOT_LIST]"
                for SNAPSHOT_LIST_ITEM in ${SNAPSHOT_LIST[*]}; do
                    einfo "virsh snapshot-delete ${ACTIVEVM} $SNAPSHOT_LIST_ITEM --metadata"
                    virsh snapshot-delete "${ACTIVEVM}" "$SNAPSHOT_LIST_ITEM" --metadata
                done

                ### DELETE TEMPORARY EXTERNAL SNAPSHOTS (FILE)
                einfo "Delete temporary external snapshot (file) and config dump of: ${ACTIVEVM}"
                edebug "$(find $BACKUP_DIR/tmp-ext-snap/${ACTIVEVM}/* -exec ls -ltrh {} + | awk '{print $9}')"
                find $BACKUP_DIR/tmp-ext-snap/"${ACTIVEVM}"/* -exec rm {} \;
            fi
            find $BACKUP_DIR/config/"${ACTIVEVM}"/* -exec rm {} \;

            ### END BACKUP
            esilent "--------- END BACKUP OF VM: ${ACTIVEVM} ---------"
        fi
    else
        enotify "Excluded ${ACTIVEVM} because it is in the exclude list"
    fi
done

if [ "$1" == "" ]; then
    esilent "--------- END BACKUP OF HOST: ${HOSTNAME} ---------\n"
fi

Log_Close
