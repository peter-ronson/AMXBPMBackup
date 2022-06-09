#!/bin/sh
#########################################################################
#
# Suspend AMX via command line utility and take file system backups of
#
# Binary TIBCO HOME
# AMX CONFIG HOME
# BPM Config (shared)
#
#########################################################################
VERSION="1.2"
#########################################################################
# Load general functions
#########################################################################
dirName=$(dirname "$0")
if [ -f "$dirName/include_functions.sh" ];then
        . "$dirName/include_functions.sh"
else
        echo "$dirName/include_functions.sh not found"
        exit 1
fi
#########################################################################
# Functions
#########################################################################
doHelp() {

    echo ""
    echo "$scriptname [ options ]"
    echo ""
    echo "-a                       Backup AMX home"
    echo "-c                       Backup config home"
    echo "-s                       Backup shared config"
    echo "-r                       Remove previous backups"
    echo "-n                       Do not backup"
    echo "-x                       Do not Check/Set AMX status"
    echo "-h                       This page"
    echo ""


}
#########################################################################
# Convert seconds to human readable form
#########################################################################
secs_to_human() {
    if [[ -z ${1} || ${1} -lt 60 ]] ;then
        min=0 ; secs="${1}"
    else
        time_mins=$(echo "scale=2; ${1}/60" | bc)
        min=$(echo ${time_mins} | cut -d'.' -f1)
        secs="0.$(echo ${time_mins} | cut -d'.' -f2)"
        secs=$(echo ${secs}*60|bc|awk '{print int($1+0.5)}')
    fi
    echo "Time Elapsed : ${min} minutes and ${secs} seconds."
}
#########################################################################
# Execute AMX command line ant for suspend
#########################################################################
doAMXSuspend() {

    mode="$1"
    $ANTHOME/ant --propFile $ANTHOME/ant.tra -f "enterprise_suspend_build.xml" "$mode" > "$OUTFILE"
    cnt=$(grep -c "ERROR -" "$OUTFILE")
    if [ $cnt -eq 0 ];then 
        ec=0
    else
        logmsg "AMX State command [$mode] KO" 3
        ec=1
    fi
    return $ec
}
doSuspend() {
    logmsg "Suspending AMX"
    doAMXSuspend suspend
    ec=$?
    rm -rf $OUTFILE
    return $ec
}
doUnSuspend() {
    logmsg "Unsuspending AMX"
    doAMXSuspend unsuspend
    ec=$?
    rm -rf $OUTFILE
    return $ec
}

doStatus() {
    
    doAMXSuspend "status"
    ec=$?
    if [ $ec -eq 0 ];then
        state=$(cat "$OUTFILE" | grep "INFO - Enterprise is in" | sed "s/^.*INFO - Enterprise is in //" | sed "s/ state//")
    else
        state=""
        logmsg "Cannot determine AMX State" 3
    fi
    echo "$state"
    return $ec 
}
#########################################################################
# Backup binary home
#########################################################################
doHome() {

    bkp="zip -rq $BACKUP_HOME/${1}_${timestamp}_amx_home.zip $TIBCO_HOME"
    logmsg "$1: $bkp"
    ssh "$1" "$bkp" > "$OUTFILE" 2>&1
    if [ $? -eq 0 ];then
        logmsg "OK"
    else    
        logmsg "AMX Home Backup failed " 3
    fi
}
#########################################################################
# Backup config home, exclude all BPM log files
#########################################################################
doConfig() {

    bkp="zip -rq $BACKUP_CONFIG/${1}_${timestamp}_config_home.zip $CONFIG_HOME -x '*/logs/*.log*'"
    logmsg "$1: $bkp"
    ssh "$1" "$bkp" > $OUTFILE 2>&1
    if [ $? -eq 0 ];then
        logmsg "OK"
    else    
        logmsg "Config Backup failed " 3
    fi
}
#########################################################################
# Backup shared config
#########################################################################
doShared() {

    logmsg "$hostname" 9
    bkp="zip -rq $BACKUP_SHARED/${hostname}_${timestamp}_shared_config.zip $SHARED_CONFIG"
    logmsg "$bkp" 
    result="$($bkp)"
    if [ $? -eq 0 ];then
        logmsg "OK"
    else    
        logmsg "Shared Config Backup failed " 3
    fi
}
#########################################################################
# Remove existing backups
#########################################################################
doRemove() {
    rmf="find $BACKUP_CONFIG -maxdepth 1 -type f -iname '*config_home.zip' -delete"
    logmsg "cmd $1: $rmf" 
    ssh "$1" "$rmf" > $OUTFILE 2>&1
    if [ $? -eq 0 ];then
        logmsg "Removed config backup OK"
    else    
        logmsg "Removing config backup failed" 3
    fi 
    rmf="find $BACKUP_HOME -maxdepth 1 -type f -iname '*amx_home.zip' -delete"
    logmsg "cmd $1: $rmf" 
    ssh "$1" "$rmf" > $OUTFILE 2>&1
    if [ $? -eq 0 ];then
        logmsg "Removed AMX home backup OK"
    else    
        logmsg "Removing AMX Home Backup failed" 3
    fi 
}
doRemoveShared() {
    rmf="find $BACKUP_SHARED -maxdepth 1 -type f -iname '*shared_config.zip' -delete"
    logmsg "cmd: $rmf" 
    result=$(find "$BACKUP_SHARED" -maxdepth 1 -type f -iname '*shared_config.zip' -delete)
    dbg "$result"
    if [ $? -eq 0 ];then
        logmsg "Removed shared backup OK"
    else    
        logmsg "Removing shared backup failed" 3
    fi 
}
#########################################################################
# START HERE
#########################################################################
homeDir=$(dirname $0)
hostname=$(hostname)
now=$(date +'%d/%m/%y %H:%M:%S')
timestamp=$(date +%y%m%d%H%M%S)
scriptname=$(basename $0)
#
REMOVEOLD=0
DOBACKUP=1
#
DOAMXHOME=0
DOCONFIG=0
DOSHARED=0
NOSTATUS=0
#
logmsg "$scriptname $VERSION $now" 9
# Load config file
if [ -f "$homeDir/../cfg/amxctrl.cfg" ];then
        CONFIGMESS="Config file $homeDir/../cfg/amxctrl.cfg"
        . "$homeDir/../cfg/amxctrl.cfg"
fi
if [ -f "$homeDir/amxctrl.cfg" ];then
        CONFIGMESS="Config file $homeDir/amxctrl.cfg"
        . "$homeDir/amxctrl.cfg"
fi
#
if [ ! "$1"X = "X" ];then
        while getopts ":nacsrhx" OPTION;
    do
        case "$OPTION" in
                n)
                    echo "No Backup"
                    DOBACKUP=0
                    ;;
                a)
                    echo "Backup AMX home"
                    DOAMXHOME=1
                    DOBACKUP=0
                    ;;
                c)  
                    echo "Backup config home"
                    DOCONFIG=1
                    DOBACKUP=0
                    ;;
                s)
                    echo "Backup shared config"
                    DOSHARED=1
                    DOBACKUP=0
                    ;;
                r)  
                    echo "Remove old backups"
                    REMOVEOLD=1
                    ;;
                x)
                    echo "No status check/change"
                    NOSTATUS=1
                    ;;
                *)
                    doHelp
                    exit 0
                    ;;
        esac
    done
fi


logmsg "$CONFIGMESS"
#
ANTHOME="$AMX_HOME/bin"
OUTFILE="/tmp/$$_out"
#
STARTTIME=$(date +%s)
#
cd "$homeDir" || exit 99
#
if [ $NOSTATUS -eq 0 ];then
    state="$(doStatus)"
    if [ $? -eq 0 ];then
        logmsg "Current state is $state"
    else
        logmsg "Error retieving status" 3
        exit 2
    fi
    if [ "$state" != "suspended" ];then
        # Suspend AMX BPM 
        doSuspend
        if [ $? -ne 0 ];then
            logmsg "Cannot suspend AMX BPM" 3
            exit 1
        fi
    else
        logmsg "AMX already suspended"
    fi
fi
#
for s in $(echo "$SERVERS" | sed "s/,/\n/g" | xargs);do

    logmsg "$s" 9
    #server=$(echo "$s" | sed 's/\n//')
    if [ $REMOVEOLD -eq 1 ];then
        logmsg "Removing Old backups"
        doRemove "$s"
    fi

    if [ $DOBACKUP -eq 1 ] || [ $DOAMXHOME -eq 1 ];then
        doHome "$s"
    fi

    if [ $DOBACKUP -eq 1 ] || [ $DOCONFIG -eq 1 ];then
        doConfig "$s"
    fi

done
#
logmsg "End of Servers"
#
if [ $REMOVEOLD -eq 1 ];then
    doRemoveShared
fi
if [ $DOBACKUP -eq 1 ] || [ $DOSHARED -eq 1 ];then
    doShared
fi
#
if [ $NOSTATUS -eq 0 ];then
    doUnSuspend
    #
    state="$(doStatus)"
    if [ $? -eq 0 ];then
        logmsg "Current state is $state"
    else
        logmsg "Error retieving status" 3
        exit 2
    fi
fi
ENDTIME=$(date +%s)
elapsed="$(expr $ENDTIME - $STARTTIME )"
logmsg "$(secs_to_human $elapsed)"
rm -f "$OUTFILE"
logmsg "The End" 9
