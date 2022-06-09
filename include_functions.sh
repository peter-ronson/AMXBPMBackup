#!/bin/sh
###################################################################################
#
# General and logging functions to be included in scripts
# 
# 12/01/2017	Peter Ronson 		Created from original amxctrl.sh script
# 30/05/2017				Added simple password obfuscation
# 12/07/2017				Updated variables and harmonised for all
#					scripts
# 13/07/2017				Added db connection string function
# 28/08/2017				Added tnsnames file string function
###################################################################################
# Version 2.1
###################################################################################
#
# General functions
#
###################################################################################
# Load the file in CONFIGFILE
###################################################################################
loadConfig() {
	# Change config file if set
	if [ ! "$1"X = "X" ];then
		CONFIGFILE="$1"
	fi
	if [ -f "$CONFIGFILE" ];then
		dbg "Loading $CONFIGFILE"
        	. "$CONFIGFILE"
	else
		if [ -f "$BASEDIR/../cfg/amxctrl.cfg" ];then
			CONFIGFILE="$BASEDIR/../cfg/amxctrl.cfg"
			dbg "Loading $CONFIGFILE"
			. "$CONFIGFILE"
		else
			logmsg "Cannot load configuration file $CONFIGFILE" 3
			exit 99
		fi
	fi
}
###################################################################################
#
# Logging functions
#
###################################################################################
###################################################################################
# Print message to files and/or console
###################################################################################
logmsg()
{
  now=`date +%d/%m/%y\ %H:%M:%S`
  case $2 in
    0) mtype="DEBUG";;
    1) mtype="INFO";;
    2) mtype="WARN";;
    3) mtype="ERROR";;
    4) mtype="DIRECT";;
    5) mtype="TITLE";;
    9) mtype="TITLE";;
    *) mtype="INFO";;
  esac
  # Check we can write to the file
  touch $LOGFILE > /dev/null 2>&1
  if [ "$?" -eq 0 ];then
        if [ -f "$LOGFILE" ]; then
                if [ $mtype = "DIRECT" ];then
                        echo "$1" >> $LOGFILE
                else
                        message="$now|$HOSTNAME|$SCRIPTNAME|$mtype| $1"
                        if [ "$mtype" = "TITLE" ];then
                                doTitle "$message"
                        else
                                echo "$message" >> $LOGFILE
                        fi
                fi
        fi
  fi

  # Always echo errors to the console

  if [ ! "$SILENT" = "1" -o "$mtype" = "ERROR" ]; then
    if [ $mtype = "DIRECT" ];then
        if [ $DEBUG = "1" ]; then
                echo "$1" 
        fi
    else
        if [ $mtype = "TITLE" ]; then
                doTitle "$1" 1
        else
                echo "$1"
        fi
    fi
  fi
}
###################################################################################
# Print title bars to screen ot file
###################################################################################
function doTitle() {
        message=$1
        screen=$2
        size=`expr length "$message"`
        #size=`expr $size + 1`
        lines=`echo "===============================================================================================================" | cut "-c1-${size}"`
        if [ "$screen" = "1" ]; then
                echo $lines
                echo $message
                echo $lines
        else
                echo $lines >> $LOGFILE
                echo $message >> $LOGFILE
                echo $lines >> $LOGFILE
        fi
}
###################################################################################
# Write debug message
###################################################################################
function dbg() {
        
        if [ "$DEBUG" = "1" ];then
        
                tmpSILENT=$SILENT
                SILENT=0
                logmsg "$1" 0
                SILENT=$tmpSILENT
        fi
        
 
}
###################################################################################
# Remove whitespace before and make the string X chars long
###################################################################################
fixLength() {
        buff=$1
        length=$2
        FIXLENGTH=$(echo "${buff}                                                                                                                                                                              " | sed 's/^ *//g' | cut -c1-"${length}")

}
###################################################################################
# Encrypt or Decrypt using simple base64 encoding
###################################################################################
encPass() {
	unencrypted="$1"
	encrypted=$(echo "$unencrypted" | base64)
}
uncPass() {
	encrypted="$1"
	unencrypted=$(echo "$encrypted" | base64 --decode)
	# echo password to allow uncPass <password> to work directly
	echo "$unencrypted"
}
###################################################################################
# Construct a tns string for database call
###################################################################################
connStr(){
	user=$1
	passwu=$2
	dbhost=$3
	dbport=$4
	dbinst=$5
	#
	passwd=$(uncPass "$passwu")
	connstr=$(echo  "${user}/__PASSWORD__@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$dbhost)(Port=$dbport))(CONNECT_DATA=(SID=$dbinst)))" | sed "s/__PASSWORD__/$passwd/")
	echo "$connstr"	
}
tnsStr(){
        dbhost=$1
        dbport=$2
        dbinst=$3
        tnsstr=$(echo  "bpm=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host=$dbhost)(Port=$dbport))(CONNECT_DATA=(SID=$dbinst)))")
        echo "$tnsstr"
}
###################################################################################
# Toggle debug if file exists in /tmp
###################################################################################
toggleDebug() {
	if [ -f "/tmp/$SCRIPTNAME.debug" ];then
		DEBUG=1
		if [ "$DEBUGSET"X = "X" ];then
			dbg "DEBUG On"
		fi
		DEBUGSET=1
	else
		if [ "$DEBUGSET" = "1" ];then
			dbg "DEBUG Off"
			DEBUG=0
			DEBUGSET=""
			
		fi
	fi
}
###################################################################################
# Std variables
###################################################################################
HOSTNAME=`hostname`
NOW=`date +%d/%m/%y\ %H:%M:%S`
TIMESTAMP=$(date +%y%m%d%H%M%S)
SCRIPTNAME=`basename $0`
BASEDIR=$(dirname $0)
###################################################################################
# Default settings
###################################################################################
#
VERSION="1.0"
SILENT=0
LOGFILE=$(echo $SCRIPTNAME | sed 's/\.sh$/\.log/')
# default configuration file
CONFIGFILE="$BASEDIR/amxctrl.cfg"
#
if [ "$1" = "encrypt" ];then
        encPass "$2"
        echo "$2 -> $encrypted"
fi
#
# The End
#
