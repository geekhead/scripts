#!/bin/bash

################# START OF SERVER BACKUP SETTINGS ##########################################

# Specify where you want the backup files to be placed.
# Rsync will move all files in here to remote backup server
BACKUP_HOME="/var/backups"

# Specify what folders you would like to backup
BACKUP_FILES="/etc /var/log /var/spool"

# Your EXCLUDE_FILE tells the script what NOT to backup. Leave it unchanged, missing or
# empty if you want to backup all files in your BACKUP_FILES. If performing a
# FULL SYSTEM BACKUP, ie. Your SOURCES is set to "/", you will need to make
# use of EXCLUDE_FILE. The file should contain directories and filenames, one per line.
# An example of a EXCLUDE_FILE would be:
# /proc/
# /tmp/
# /mnt/
# *.SOME_KIND_OF_FILE
EXCLUDE_FILES=/scripts/.exclude_files

# These are the files that store the metadata. These should not be changed
INCR_FILE=/scripts/.incr_list
DIFF_FILE=/scripts/.diff_list
FULL_FILE=/scripts/.full_list

# Specify date format. This gets attached to the filenames
BDATE=`date +%F_%H-%M`

# Backup file name. Leave blank
BFILE=""

#################### END OF SERVER BACKUP SETTINGS ########################################

#################### START OF RSYNC SETTINGS ##########################################

# Directories to backup. This should be equal to the BACKUP_HOME setting above
RSOURCES=$BACKUP_HOME

# IP or FQDN of Remote Machine
RMACHINE="bryant"

# DNS name of source computer. Must match name of folder on remote server.
SMACHINE="rdu-wiki-01"

# Remote username
RUSER=svcwrsync

# Location of passphraseless ssh keyfile
RKEY="/root/rsync-key"

# Directory to backup to on the remote machine. This is where your backup(s) will be stored
# :: NOTICE :: -> Make sure this directory is empty or contains ONLY backups created by
#	                        this script and NOTHING else. Exclude trailing slash!
RTARGET="/cygdrive/s/fileshares/linuxbackups/$SMACHINE"

# Set the number of backups to keep on the remote server (greater than 1). Ensure you have adaquate space.
ROTATIONS=7

# Comment out the following line to disable verbose output
#VERBOSE="-v"

#################### END OF RSYNC SETTINGS ###########################################




#######################################
########DO_NOT_EDIT_BELOW_THIS_POINT#########
#######################################


############## START OF SERVER BACKUP PROCESS ##########################################

case "$1" in
  -f|-full)
    BFILE=$BACKUP_HOME/`hostname`.full.$BDATE.tgz
    rm -f $INCR_FILE $DIFF_FILE $FULL_FILE
    tar $VERBOSE -czf $BFILE --exclude-from $EXCLUDE_FILES -g $FULL_FILE $BACKUP_FILES 2>&1 >/dev/null
    cp $FULL_FILE $DIFF_FILE
    cp $FULL_FILE $INCR_FILE
    BTYPE="full"
    ;;
  -d|-diff)
    BFILE=$BACKUP_HOME/`hostname`.diff.$BDATE.tgz
    tar $VERBOSE -czf $BFILE --exclude-from $EXCLUDE_FILES -g $DIFF_FILE $BACKUP_FILES 2>&1 >/dev/null
    cp $FULL_FILE $DIFF_FILE
    BTYPE="diff"
    ;;
  -i|-incr)
    BFILE=$BACKUP_HOME/`hostname`.incr.$BDATE.tgz
    tar $VERBOSE -czf $BFILE --exclude-from $EXCLUDE_FILES -g $INCR_FILE $BACKUP_FILES 2>&1 >/dev/null
    BTYPE="incr"
    ;;
  -nobackup)
   
    ;;
  *)
    echo USAGE: $0 \<-f\|-d\|-i\> \<-s\|-sync-test\>
    echo "SWITCHES:"
    echo "-f or -full: Full backup of system"
    echo "-d or -diff: Differential backup of system"
    echo "-i or -incr: Incremental backup of system"
    echo "-nobackup: Do not perform a system backup. Use this if you want to only perform an Rsync operation"
    echo "-sync-test: Perform an Rsync test on remote server $RMACHINE"
    echo "-s or -sync: Rsync the folder $BACKUP_HOME to remote server $RMACHINE"
    exit
    ;;
esac




############## END OF SERVER BACKUP PROCES ###########################################


############# START OF RSYNC BACKUP TO REMOTE SERVER #################################
case "$2" in
  -sync-test)
        if [ ! -f $RKEY ]; then
      echo "Couldn't find ssh keyfile!"
      echo "Exiting..."
      exit 2
    fi
    
    if ! ssh $VERBOSE -i $RKEY $RUSER@$RMACHINE "test -x $RTARGET"; then
      echo "Target directory on remote machine doesn't exist or bad permissions."
      echo "Exiting..."
      exit 2
    else
        echo "Succesffuly connected to remote server $RMACHINE"
    fi
  ;;
  -sync-connect)
    ssh $VERBOSE -i $RKEY $RUSER@$RMACHINE



  ;;
  -s|-sync)
  
  
      if [ ! -f $RKEY ]; then
      echo "Couldn't find ssh keyfile!"
      echo "Exiting..."
      exit 2
    fi
    
    if ! ssh $VERBOSE -i $RKEY $RUSER@$RMACHINE "test -x $RTARGET"; then
      echo "Target directory on remote machine doesn't exist or bad permissions."
      echo "Exiting..."
      exit 2
    fi
    
    if [ ! $ROTATIONS -gt 1 ]; then
      echo "You must set ROTATIONS to a number greater than 1!"
      echo "Exiting..."
      exit 2
    fi
    
    #### BEGIN ROTATION SECTION ####
    #BACKUP_NUMBER=1
    if [ -n "$BTYPE" ]; then
    BACKUP_NUMBER=1
    # incrementor used to determine current number of backups
    
    # list all backups in reverse (newest first) order, set name of oldest backup to $backup
    # if the retention number has been reached.
    for backup in `ssh $VERBOSE -i $RKEY $RUSER@$RMACHINE "ls -Xr $RTARGET/*$BTYPE*"`; do
    	if [ $BACKUP_NUMBER -eq 1 ]; then
    		NEWEST_BACKUP="$backup"
    	fi
    
    	if [ $BACKUP_NUMBER -eq $ROTATIONS ]; then
    		OLDEST_BACKUP="$backup"
    		break
    	fi
    
    	let "BACKUP_NUMBER=$BACKUP_NUMBER+1"
    done
    
    # Check if $OLDEST_BACKUP has been found. If so, delete it.
    if [ $OLDEST_BACKUP ]; then
      ssh $VERBOSE -i $RKEY $RUSER@$RMACHINE "rm -f $OLDEST_BACKUP"
    fi
    
    fi  
    #### END ROTATION SECTION ####
    
   
    echo "Verifying Sources..."
    for source in $RSOURCES; do
    	echo "Checking $source..."
    	if [ ! -x $source ]; then
         echo "Error with $source!"
         echo "Directory either does not exist, or you do not have proper permissions."
         exit 2
       fi
    done
    
   echo "Sources verified. Running rsync..."   
   rsync $VERBOSE -az "ssh -i $RKEY" $RSOURCES/ $RUSER@$RMACHINE::$SMACHINE
	        
   # Delete all the files in the backup directory after a successfull rsync operation
   rm $VERBOSE -f $BACKUP_HOME/*  
 
  ;;
  
  *)

   ;;
esac