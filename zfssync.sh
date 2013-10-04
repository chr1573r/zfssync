#!/bin/bash
# zfssync.sh - ZFS replication script
# WARNING - The code quality is mediocre at best, use at your own responibility!
# Written by Christer Jonassen - cjdesigns.no
# Licensed under CC BY-NC-SA 3.0 (check LICENCE file or http://creativecommons.org/licenses/by-nc-sa/3.0/ for details.)
# Made possible by the wise *nix and BSD people sharing their knowledge online
#
# Check README for instructions

# Variables
APPVERSION="1.0"
CONFIGFILE="test.cfg"
STATUS=""$DEF"Idle"

# Pretty colors for the terminal:
DEF="\x1b[0m"
WHITE="\e[0;37m"
LIGHTBLACK="\x1b[30;01m"
BLACK="\x1b[30;11m"
LIGHTBLUE="\x1b[34;01m"
BLUE="\x1b[34;11m"
LIGHTCYAN="\x1b[36;01m"
CYAN="\x1b[36;11m"
LIGHTGRAY="\x1b[37;01m"
GRAY="\x1b[37;11m"
LIGHTGREEN="\x1b[32;01m"
GREEN="\x1b[32;11m"
LIGHTPURPLE="\x1b[35;01m"
PURPLE="\x1b[35;11m"
LIGHTRED="\x1b[31;01m"
RED="\x1b[31;11m"
LIGHTYELLOW="\x1b[33;01m"
YELLOW="\x1b[33;11m"

##################
# FUNCTIONS BEGIN:

timeupdate() # Sets current time into different variables. Used for timestamping etc.
{
	DATE=$(date +"%d-%m-%Y") 			# 12-04-2013 (day-month-year)
	SHORTDATE=$(date +"%d-%m-%y")		# 12-04-13
	TINYDATE=$(date +"%Y%m%d")			# 20130412
	DATEFUZZY=$(date +"%a %d %b")		# Fri 12 Apr
	MCSTAMP=$(date +"%Y-%m-%d %R:%S")	# 2013-04-12 15:34:13 (mc server log format)
	UNIXSTAMP=$(date +%s)				# 1365773648 (unix timestamp)
	NOWSTAMP=$(date +"%Hh%Mm%Ss") 		# 15h34m34s
	HM=$(date +"%R") 					# 15:34
	HMS=$(date +"%R:%S") 				# 15:34:34
	HOUR=$(date +"%H") 					# 15
	MINUTE=$(date +"%M") 				# 34
	SEC=$(date +"%S") 					# 56

	#if [ -f yesterday.sh ] ; then ut "Neccessary workaround script \"yesteday.sh\" found"; else status error; ut "Neccessary workaround script \"yesteday.sh\" NOT found!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
	#if [ -f yesterday.sh ] ; then continue; else echo  "$(date +"%Y-%m-%d %R:%S") yesterday.sh not found, aborting" >>zsyncdebug.log; echo "timeupdate() error: Neccessary workaround script \"yesteday.sh\" NOT found!"; echo "zfssync.sh will now terminate."; sleep 2; exit; fi
	YESTERDAY=$(./yesterday.sh)			# 20130411 (Dirty workaround, since FreeNAS does not have GNU/date. Script found here: http://www.digitalinternals.com/131/20090705/calculate-yesterday-date-in-unix-shell-script/)
}


ut()
{
	echo -e ""$LIGHTGRAY"["$DEF""$RED"zs"$LIGHTGRAY"]"$DEF"[$STATUS][$(date +"%a %d %b, %R:%S")]"$LIGHTYELLOW":"$DEF" $1"
	logg "$1"

}

status()
{
	case "$1" in
		idle)
		STATUS=""$DEF"Idle"
		CLEARTEXTSTATUS="Idle"
		RHOST="<idle>"
		;;

		busy)
		STATUS=""$YELLOW"Busy"$DEF""
		CLEARTEXTSTATUS="Busy"
		;;

		sync)
		STATUS=""$LIGHTGREEN"Sync"$DEF""
		CLEARTEXTSTATUS="Sync"
		;;

		error)
		STATUS=""$LIGHTRED"HALT"$DEF""
		CLEARTEXTSTATUS="HALT"
		;;
	esac
	logg "Status set to $1"
}

logg()
{
timeupdate
		echo "$MCSTAMP [$CLEARTEXTSTATUS][$RHOST] $1">>zsyncsys.log
		echo "$MCSTAMP [$CLEARTEXTSTATUS][$RHOST] $1">>zsyncdebug.log
}

splash() # display logo
{
	clear
	echo
	echo
	echo
	echo 
	echo
	echo
	echo
	echo -e "          "$RED"         .8888b                                              "
	echo -e "                   88   \"                                              "
	echo -e "          d888888b 88aaa  .d8888b. .d8888b. dP    dP 88d888b. .d8888b. "
	echo -e "             .d8P' 88     Y8ooooo. Y8ooooo. 88    88 88'  \`88 88'  \`"" "
	echo -e "           .Y8P    88           88       88 88.  .88 88    88 88.  ... "
	echo -e "          d888888P dP     \`88888P' \`88888P' \`8888P88 dP    dP \`88888P' "
	echo -e "          "$WHITE"ooooooooooooooooooooooooooooooooooo~~~~"$RED".88~"$WHITE"oooooooooooooooooo"
	echo -e "          "$RED"                                   d8888P     "$LIGHTBLACK"Cj Designs 2013"$DEF""
}

checkping() # Check if remote system is pingable
{
	ut "   Attempting ping..."
	ping -q -c 4 -W3 $RHOST&> /dev/null # Ping remote host 4 times, with a timeout of 3 seconds
		if [ $? == 0 ]; then
			PINGCHECK="OK"
			ut "     -> Target is "$GREEN"pingable"$DEF"!"
		else
			PINGCHECK="ERR"
			status error
			ut "     -> Target is "$RED"not pingable"$DEF""
			ut "We can not proceed."
			ut "zfssync.sh will now terminate."
			sleep 2
			exit
		fi
}

checkssh()
{
	ut "   Attempting SSH connection..."
	ssh -n -i $KEY -p $PORT -q $RHOST exit
		if [ $? == 0 ]; then
			SSHCHECK="OK"
			ut "     -> SSH test connection "$GREEN"successful"$DEF"!"
		else
			SSHCHECK="ERR"
			status error
			ut "     -> SSH test connection "$RED"unsuccessful"$DEF""
			ut "We can not proceed."
			ut "zfssync.sh will now terminate."
			sleep 2
			exit
		fi
}

idlewait()
{
	ut "Checking if zfssleep.txt is present.."
	if [ -f zfssleep.txt ]; then status idle; ut "Entering deep sleep (zfssleep.txt detected)"; fi
	
	while [ -f zfssleep.txt ]
	do
		COUNTDOWN=1800
		ut "Waiting until told otherwise. Re-checking for go-signal in "$LIGHTGRAY"$COUNTDOWN"$DEF" second(s)"
		until [ $COUNTDOWN == 0 ]; do
			sleep 1
			COUNTDOWN=$(( COUNTDOWN - 1 ))
		done
	done
	ut "zfssleep.txt not detected, re-initializing zfssync"
}


zfsrep()
{
	ut
	status busy
	ut ""$YELLOW"zfssync init..."$DEF""
	ut 
	while read CURRENTDATASET # The script will repeat below until CTRL-C is pressed
		do
			status busy
			timeupdate
			ut "Preparing next replication..."
			# Blank variables before we read CURRENTDATASET
			DESCRIPTION=
			SNAPSHOT=
			PREVSNAPSHOT=
			KEY=
			PORT=
			RHOST=
			TARGETFS=
			ut "Reading configuration..."
			ut "     -> "$CYAN"$CURRENTDATASET"$DEF""
			source $CURRENTDATASET
			if [ -z "$DESCRIPTION" ]; then status error; ut "DESCRIPTION not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$PREVSNAPSHOT" ]; then status error; ut "PREVSNAPSHOT not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$SNAPSHOT" ]; then status error; ut "SNAPSHOT not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$KEY" ]; then status error; ut "KEY not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$PORT" ]; then status error; ut "PORT not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$RHOST" ]; then status error; ut "RHOST not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$TARGETFS" ]; then status error; ut "TARGETFS not set, please check config!"; ut "zfssync.sh will now terminate."; sleep 2; exit; fi
			ut
			ut "Loaded config:"
			ut "   Description:                  "$CYAN"$DESCRIPTION"$DEF""
			ut "   Previous snapshot:            "$CYAN"$PREVSNAPSHOT"$DEF""
			ut "   Snapshot that will be pushed: "$CYAN"$SNAPSHOT"$DEF""
			ut "   Authentication key:           "$CYAN"$KEY"$DEF""
			ut "   Port used for SSH connection: "$CYAN"$PORT"$DEF""
			ut "   Remote system:                "$CYAN"$RHOST"$DEF""
			ut "   Target filesystem:            "$CYAN"$TARGETFS"$DEF""
			ut
			ut "Checking remote system:"
			checkping
			ut
			checkssh
			ut
			status sync
			ut "Ready for ZFS replication! - 3"
			sleep 1
			ut "Ready for ZFS replication! - 2"
			sleep 1
			ut "Ready for ZFS replication! - 1"
			sleep 1
			ut "GO!"
			
			ut "zfs send -i $PREVSNAPSHOT $SNAPSHOT | dd | dd obs=1m | ssh -i $KEY -p $PORT $RHOST zfs receive $TARGETFS"
			zfs send -i $PREVSNAPSHOT $SNAPSHOT | dd | dd obs=1m | ssh -i $KEY -p $PORT $RHOST zfs receive $TARGETFS
			
			ut
			ut "### Finished current dataset ($DESCRIPTION)"
			status busy
			ut
			ut
	done < cfg.lst

	ut "Looks like we are done for now, creating zfssleep.txt"
	echo "Done for now.">zfssleep.txt
	ut "##### Finished syncing all datasets!"
	status idle
	ut
}

# FUNCTIONS END:
##################


# The actual runscript:

trap "{ echo zfssync $APPVERSION terminated at `date`; exit; }" SIGINT SIGTERM EXIT # Set trap for catching Ctrl-C and kills, so we can reset terminal upon exit

splash
clear





while true
	do
		idlewait
		zfsrep
	done
status error
ut "zfsync halt"