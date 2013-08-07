#!/bin/sh
#
# Author: David Peterson
# multi_rbackup.sh -- secure backup to a remote machine using rsync.
#

# Directories to backup. Separate with a space. Exclude trailing slash!
SOURCES="/etc /var/spool /var/www /var/log /db_backups "

# IP or FQDN of Remote Machine
RMACHINE="server1"

# Remote username
RUSER=svcwrsync

# Location of passphraseless ssh keyfile
RKEY="/root/rsync-key"

# Directory to backup to on the remote machine. This is where your backup(s) will be stored
# :: NOTICE :: -> Make sure this directory is empty or contains ONLY backups created by
#	                        this script and NOTHING else. Exclude trailing slash!
RTARGET="/cygdrive/v/backups/server1"

# DNS name of source computer. Must match name of folder on remote server.
SMACHINE="server1"

# Set the number of backups to keep (greater than 1). Ensure you have adaquate space.
ROTATIONS=7

# Your EXCLUDE_FILE tells rsync what NOT to backup. Leave it unchanged, missing or
# empty if you want to backup all files in your SOURCES. If performing a
# FULL SYSTEM BACKUP, ie. Your SOURCES is set to "/", you will need to make
# use of EXCLUDE_FILE. The file should contain directories and filenames, one per line.
# An example of a EXCLUDE_FILE would be:
# /proc/
# /tmp/
# /mnt/
# *.SOME_KIND_OF_FILE
EXCLUDE_FILE="/path/to/your/exclude_file.txt"

# Comment out the following line to disable verbose output
#VERBOSE="-v"

#######################################
########DO_NOT_EDIT_BELOW_THIS_POINT#########
#######################################

if [ ! -f $RKEY ]; then
  echo "Couldn't find ssh keyfile!"
  echo "Exiting..."
  exit 2
fi

if ! ssh -i $RKEY $RUSER@$RMACHINE "test -x $RTARGET"; then
  echo "Target directory on remote machine doesn't exist or bad permissions."
  echo "Exiting..."
  exit 2
fi

# Set name (date) of backup.
BACKUP_DATE="`date +%F_%H-%M`"

if [ ! $ROTATIONS -gt 1 ]; then
  echo "You must set ROTATIONS to a number greater than 1!"
  echo "Exiting..."
  exit 2
fi

#### BEGIN ROTATION SECTION ####

BACKUP_NUMBER=1
# incrementor used to determine current number of backups

# list all backups in reverse (newest first) order, set name of oldest backup to $backup
# if the retention number has been reached.
for backup in `ssh -i $RKEY $RUSER@$RMACHINE "ls -dXr $RTARGET/*/"`; do
	if [ $BACKUP_NUMBER -eq 1 ]; then
		NEWEST_BACKUP="$backup"
	fi

	if [ $BACKUP_NUMBER -eq $ROTATIONS ]; then
		OLDEST_BACKUP="$backup"
		break
	fi

	let "BACKUP_NUMBER=$BACKUP_NUMBER+1"
done

# Check if $OLDEST_BACKUP has been found. If so, rotate. If not, create new directory for new backup.
if [ $OLDEST_BACKUP ]; then
  # Set oldest backup to current one
  #ssh -i $RKEY $RUSER@$RMACHINE "mv $OLDEST_BACKUP $RTARGET/$BACKUP_DATE"
  ssh -i $RKEY $RUSER@$RMACHINE "rm -r -f $OLDEST_BACKUP && mkdir $RTARGET/$BACKUP_DATE"
else
  ssh -i $RKEY $RUSER@$RMACHINE "mkdir $RTARGET/$BACKUP_DATE"
fi


# Update current backup using hard links from the most recent backup
#if [ $NEWEST_BACKUP ]; then
#  ssh -i $RKEY $RUSER@$RMACHINE "cp -al $NEWEST_BACKUP $RTARGET/$BACKUP_DATE"
#fi

#### END ROTATION SECTION ####

# Check to see if rotation section created backup destination directory
if ! ssh -i $RKEY $RUSER@$RMACHINE "test -d $RTARGET/$BACKUP_DATE"; then
  echo "Backup destination not available."
  echo "Make sure you have write permission in RTARGET on Remote Machine."
  echo "Exiting..."
  exit 2
fi

echo "Verifying Sources..."
for source in $SOURCES; do
	echo "Checking $source..."
	if [ ! -x $source ]; then
     echo "Error with $source!"
     echo "Directory either does not exist, or you do not have proper permissions."
     exit 2
   fi
done

if [ -f $EXCLUDE_FILE ]; then
EXCLUDE="--exclude-from=$EXCLUDE_FILE"
fi

echo "Sources verified. Running rsync..."
for source in $SOURCES; do

  # Create directories in $RTARGET to mimick source directory hiearchy
  if ! ssh -i $RKEY $RUSER@$RMACHINE "test -d $RTARGET/$BACKUP_DATE/$source"; then
    ssh -i $RKEY $RUSER@$RMACHINE "mkdir -p $RTARGET/$BACKUP_DATE/$source"
  fi

  rsync $VERBOSE $EXCLUDE -az --delete "ssh -i $RKEY" $source/ $RUSER@$RMACHINE::$SMACHINE/$BACKUP_DATE/$source/

done

exit 0
