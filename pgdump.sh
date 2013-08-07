#!/bin/bash
#
# Author: David Peterson
# Description: Postgres backup script to be run from a central backup/cron server.
#


################# START OF SERVER BACKUP SETTINGS ##########################################

# Specify where you want the backup files to be placed.
# Rsync will move all files in here to remote backup server
BACKUP_LOCATION="/backups/postgres"

# Specify date format. This gets attached to the filenames
BDATE=`date +%F_%H-%M`

# Specify the location of the pg_dump script
PGDUMP="/usr/local/pgsql-8.2.1/bin/pg_dump"

# Specify the location of the pg_dumpall script
PGDUMPALL="/usr/local/pgsql-8.2.1/bin/pg_dumpall"

# Comment out the following line to disable verbose output
VERBOSE="-v"

#################### END OF SERVER BACKUP SETTINGS ########################################



#######################################
########DO_NOT_EDIT_BELOW_THIS_POINT#########
#######################################


############## START OF SERVER BACKUP PROCESS ##########################################

if [ $# -ne 3 ]
then
    echo "Error in $0 - Invalid Argument Count"
    echo "Syntax: $0 <<hostname>> <<port>> <<database>>"
    exit
fi




############## END OF SERVER BACKUP PROCES ###########################################

# Backup database roles first
$PGDUMPALL -g -h $1 -p $2 -U postgres > $BACKUP_LOCATION/$1_$2-postgres_roles.sql

echo "Database $3 being backed up...."
FILE_NAME=$1_$2-$3-$BDATE.tar
$PGDUMP --file=$BACKUP_LOCATION/$FILE_NAME --format=t --host=$1 --port=$2 --username=postgres $3

# Let's compress the tar file to save space
tar --remove-files -czvf $BACKUP_LOCATION/$1_$2-$3-$BDATE.tgz $BACKUP_LOCATION/$FILE_NAME

echo "Database $3 backup from $1 complete...."
