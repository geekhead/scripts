#!/bin/sh
# Author: David Peterson
# fix_folderlimit.sh -- On the GPFS file system on Scale, there is a 64K folder limit within one folder. 
# Description: This script will take a folder and move all the sub-directories into another folder and create symlinks, move them to a new directory and create symlinks for them
# Date Created: 2/16/2011
# Date Modified:
#


###############################################################################
### Get input from the user for each variable
###############################################################################
echo ""
echo ""
echo "Please enter a SOURCE PATH"
echo "The full path to the folder that has too many subfolders in it"
echo "Example: /{nfs mount to scale}/dir/folder1"
read SOURCE_PATH
echo ""
echo "Please enter a TARGET PATH"
echo "The full path to the folder that we will be copying to."
echo "All the subfolders in the SOURCE PATH will be copied to the TARGET PATH"
echo "Example: /{nfs mount to scale}/dir/test/folder2/"
read TARGET_PATH
echo ""
echo "Please enter a SYMLINK PATH"
echo "This is used for a relative path to the TARGET PATH since this script will CD into the SOURCE PATH when creating the symlinks."
echo "This will be the same folder that you specified as a TARGET PATH but with a ../ in front of it"
echo "Example: ../folder2"
read SYMLINK_PATH

echo ""
echo "Please confirm the following settings and type PROCEED to continue"
echo "SOURCE_PATH = $SOURCE_PATH"
echo "TARGET_PATH = $TARGET_PATH"
echo "SYMLINK_PATH = $SYMLINK_PATH"
echo ""
read VERIFY

if [ "$VERIFY" != "PROCEED" ]; then
     echo "You need to verify your settings. Exiting..."
     exit
fi


# Date used in the logfile
DATE=`date +%F_%H-%M`

# File that contains the directory listings to copy
DIRFILE="/tmp/fix_folderlimit_dirlist_$DATE.txt"

# Log file to output status to
LOGFILE="/tmp/fix_folderlimit_$DATE.log"

# CD into the directory to copy from
cd $SOURCE_PATH


# Check if the source path folder exists and if not exit
if [ ! -d $SOURCH_PATH ]
then
    echo "Can't find the sourch path, exiting..."
    exit
fi


echo "" >> $LOGFILE
echo "###############################################################################" >> $LOGFILE
echo "# fix_folderlimit.sh script on $DATE" >> $LOGFILE
echo "###############################################################################" >> $LOGFILE
echo "" >> $LOGFILE


# Check if the target path folder exists and if not create it and set the proper perms
if [ ! -d $TARGET_PATH ]
then
    mkdir -p $TARGET_PATH
    chown 1000:1000 $TARGET_PATH
    chmod 777 $TARGET_PATH
    echo "#"
    echo "# $TARGET_PATH doesn't exist so creating it and setting the proper perms"
    echo "#"
fi


# Find all the directories in the source path and create the directory listing file
echo "Finding all the directories in $SOURCE_PATH and creating the directory listing file..."
ls -l $SOURCE_PATH | egrep "^d" | awk '{print $9}' > $DIRFILE


# Lets make sure the $DIRFILE was created and is readable
if [ ! -r $DIRFILE ];
then
     echo "Error reading $DIRFILE. Exiting..."
fi


# We now need to move all the directories into the target path
cat $DIRFILE | while read DIR ; do

echo "" >> $LOGFILE
echo "#" >> $LOGFILE
echo "# Moving Directory: $DIR" >> $LOGFILE
echo "#" >> $LOGFILE
echo "Moving Directory: $SOURCE_PATH/$DIR -  > $TARGET_PATH"
mv -v $DIR $TARGET_PATH >> $LOGFILE 2>&1

done


# We now need to create the symlinks
cat $DIRFILE | while read DIR ; do

echo "" >> $LOGFILE
echo "#" >> $LOGFILE
echo "# Creating symlink for Directory: $DIR" >> $LOGFILE
echo "#" >> $LOGFILE
echo "Creating symbolic link '$DIR' to '$SYMLINK_PATH/$DIR'"

ln -s -v $SYMLINK_PATH/$DIR $DIR >> $LOGFILE 2>&1

done

echo ""
echo "Script has finished."

exit 0
