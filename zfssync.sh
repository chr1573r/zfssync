#!/bin/bash
# zfssync.sh - ZFS replication script
# Written by Christer Jonassen - cjdesigns.no
# Licensed under CC BY-NC-SA 3.0 (check LICENCE file or http://creativecommons.org/licenses/by-nc-sa/3.0/ for details.)
# Made possible by the wise *nix and BSD people sharing their knowledge online
#
# Check README for instructions

# Variables
APPVERSION="1.0"
CONFIGFILE="test.cfg"

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
	echo -e "   Attempting ping..."
	ping -q -c 4 -W3 $RHOST&> /dev/null # Ping remote host 4 times, with a timeout of 3 seconds
		if [ $? == 0 ]; then
			pingcheck="OK"
			echo -e "     -> Target is "$GREEN"pingable"$DEF"!"
		else
			pingcheck="ERR"
			echo -e "     -> Target is "$RED"not pingable"$DEF""
			echo Abort!
		fi
}

checkssh()
{
	echo -e "   Attempting SSH connection..."
	ssh -i $KEY -p $PORT -q $RHOST exit
		if [ $? == 0 ]; then
			sshcheck="OK"
			echo -e "     -> SSH test connection "$GREEN"successful"$DEF"!"
		else
			sshcheck="ERR"
			echo -e "     -> SSH test connection "$RED"unsuccessful"$DEF""
			echo Abort!
		fi
}

# FUNCTIONS END:
##################


# The actual runscript:

#trap "{ reset; clear;echo zfssync $APPVERSION terminated at `date`; exit; }" SIGINT SIGTERM EXIT # Set trap for catching Ctrl-C and kills, so we can reset terminal upon exit

splash
clear


#while true # The script will repeat below until CTRL-C is pressed
#	do
		timeupdate
		echo -e ""$YELLOW"zfssync init..."$DEF""
		echo
		echo -e "Reading config..."
		source test.cfg
		echo
		echo -e "Loaded settings:"
		echo -e "   Snapshot that will be pushed: "$CYAN"$SNAPSHOT"$DEF""
		echo -e "   Authentication key: "$CYAN"$KEY"$DEF""
		echo -e "   Port used for SSH connection: "$CYAN"$PORT"$DEF""
		echo -e "   Remote system: "$CYAN"$RHOST"$DEF""
		echo -e "   Target filesystem: "$CYAN"$TARGETFS"$DEF""
		echo
		echo -e "Checking remote system:"
		checkping
		echo
		checkssh
		echo
		echo Ready for ZFS replication!
		echo
		echo "zfs send $SNAPSHOT | ssh -i $KEY -p $PORT $RHOST zfs receive -F $TARGETFS"
#	done
