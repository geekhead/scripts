#!/bin/sh
#
# Author: David Peterson
# postgres_backup.sh -- Script to backup a local postgreSQL databases.
#

# Set name (date) of backup.
BACKUP_DATE="`date +%F_%H-%M`"

# Databases you would like to backup. Separate multiple databases with a space
DATABASES="postgres template1 template0"

# Specify the location of the pg_dump script
PGDUMP="/usr/local/pgsql/bin/pg_dump"

# Specify the location of the pg_dumpall script
PGDUMPALL="/usr/local/pgsql/bin/pg_dumpall"

# Specify where you would like the backups to reside
BACKUP_LOCATION="/pgbackups"

# Postgres username that has admin rights
USERNAME="postgres"

# The number of backups to maintain for each database.
ROTATIONS=7



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

# Backup database roles first
$PGDUMPALL -g --username=$USERNAME > $BACKUP_LOCATION/postgres_roles.sql

for database in $DATABASES; do

echo "Database $database being backed up...."
FILE_NAME=$database-$BACKUP_DATE.tar
$PGDUMP --file=$BACKUP_LOCATION/$FILE_NAME --format=t --host=localhost --username=$USERNAME $database

# Let's compress the tar file to save space
tar --remove-files -czvf $BACKUP_LOCATION/$database-$BACKUP_DATE.tgz $BACKUP_LOCATION/$FILE_NAME

echo "Database $database backup complete...."

done

exit 0

