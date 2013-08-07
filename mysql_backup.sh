#!/bin/sh
#
# Author: David Peterson
# mysql_backup.sh -- Script to backup local MySQL databases.
#

# Set name (date) of backup.
BACKUP_DATE="`date +%F_%H-%M`"

# Databases you would like to backup. Separate multiple databases with a space
DATABASES="mysql test1 test2"

# Specify the location of the mysqldump script
MYSQLDUMP="/usr/bin/mysqldump --password=test123"

# Specify where you would like the backups to reside
BACKUP_LOCATION="/var/backups"

# mySQL username that has admin rights
USERNAME="root"

# Hostname of this server
HOSTNAME=`hostname`

# The number of backups to maintain for each database.
ROTATIONS=5



if [ ! $ROTATIONS -gt 1 ]; then
  echo "You must set ROTATIONS to a number greater than 1!"
  echo "Exiting..."
  exit 2
fi

########## BEGIN ROTATION SECTION ###########################
for database in $DATABASES; do

BACKUP_NUMBER=1
# incrementor used to determine current number of backups

# list all backups in reverse (newest first) order, set name of oldest backup to $backup
# if the retention number has been reached.
for backup in `ls -Xr $BACKUP_LOCATION | grep $database`; do
        if [ $BACKUP_NUMBER -eq 1 ]; then
                NEWEST_BACKUP="$backup"
        fi

        if [ $BACKUP_NUMBER -eq $ROTATIONS ]; then
                OLDEST_BACKUP="$backup"
                break
        fi

        let "BACKUP_NUMBER=$BACKUP_NUMBER+1"
done

# Check if $OLDEST_BACKUP has been found. If so, remove it to prevent the folder from getting to big
if [ $OLDEST_BACKUP ]; then
  # Remove the oldest backup
  rm -f $OLDEST_BACKUP
fi

done

####### END OF ROTATION SECTION ####################################

echo "Backing up databases..."
for database in $DATABASES; do

echo "Database $database being backed up...."
FILE_NAME=$HOSTNAME-mySQL-$database.sql

$MYSQLDUMP -h $HOSTNAME -u $USERNAME -q $database > $BACKUP_LOCATION/$FILE_NAME

# Let's add and compress the backups to a tar file
tar --remove-files -czvf $BACKUP_LOCATION/$HOSTNAME-mySQL-$database.tgz $BACKUP_LOCATION/$FILE_NAME

echo "Database $database backup complete...."

done

exit 0
