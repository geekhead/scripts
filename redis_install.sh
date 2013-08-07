#!/bin/bash
#
# Author: David Peterson
# Description: Install a new redis instance for a client
#

REDIS_TEMPLATE_DIR=/scripts/redis

if [ $# -ne 2 ]
then
    echo "Error in $0 - Invalid Argument Count"
    echo "Syntax: $0 <<redis_port>> <<redis_pass>>"
    exit
fi

REDIS_PORT=$1
REDIS_PASS=$2
HOST=`hostname`

if [ $HOST == "cs1-redis-01" ]; then
	OTHER_HOST=cs1-redis-02
else
	OTHER_HOST=cs1-redis-01
fi

# Make data directory
mkdir /var/lib/redis/$REDIS_PORT
ssh $OTHER_HOST mkdir /var/lib/redis/$REDIS_PORT

# Create config file
echo "creating config file..."
cp $REDIS_TEMPLATE_DIR/redis.conf.tpl /etc/redis/$REDIS_PORT.conf
sed -i "s/{port}/$REDIS_PORT/g" /etc/redis/$REDIS_PORT.conf
sed -i "s/{pass}/$REDIS_PASS/g" /etc/redis/$REDIS_PORT.conf

# Create startup script
echo "creating startup scripts..."
cp $REDIS_TEMPLATE_DIR/redis_port.tpl /etc/init.d/redis_$REDIS_PORT
ssh $OTHER_HOST cp $REDIS_TEMPLATE_DIR/redis_port.tpl /etc/init.d/redis_$REDIS_PORT
sed -i "s/{port}/$REDIS_PORT/g" /etc/init.d/redis_$REDIS_PORT
ssh $OTHER_HOST sed -i "s/{port}/$REDIS_PORT/g" /etc/init.d/redis_$REDIS_PORT
chkconfig --add /etc/init.d/redis_$REDIS_PORT
chkconfig redis_$REDIS_PORT on
ssh $OTHER_HOST chkconfig --add /etc/init.d/redis_$REDIS_PORT
ssh $OTHER_HOST chkconfig /etc/init.d/redis_$REDIS_PORT on
service redis_$REDIS_PORT start
ssh $OTHER_HOST service redis_$REDIS_PORT start

# Set up slave redis server
echo "setting up slave server..."
ssh $OTHER_HOST redis-cli -h 127.0.0.1 -p $REDIS_PORT -a $REDIS_PASS slaveof $HOST $REDIS_PORT

# Verify redis setup
sleep 5s
echo "Verify Master Redis Server..."
redis-cli -h 127.0.0.1 -p $REDIS_PORT -a $REDIS_PASS info
echo ""
echo "Verify Slave Redis Server..."
ssh $OTHER_HOST redis-cli -h 127.0.0.1 -p $REDIS_PORT -a $REDIS_PASS info

