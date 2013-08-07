#!/bin/bash
#
# Description: Server setup script that will configure the network interfaces, ip addresses, and hostname on CentOS
# Created By: David Peterson
# Modified By:
#


ROOT_UID=0      # Only users with $UID 0 have root privileges.
E_NOTROOT=87    # Non-root exit error.
NETCONFIGDIR=/etc/sysconfig/network-scripts       # location of the network scripts
NETWORKFILE=/etc/sysconfig/network


# Check if we're running the script as root
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit $E_NOTROOT
fi


######################## Global Functions #######################################################
get_hostname ()
{
        echo -n "Please enter the hostname: "
        read HOSTNAME
        if [ -z "$HOSTNAME" ]
           then
                echo "Hostname cannot be blank."
                get_hostname
        fi

}

get_dhcp()
{
        echo -n "Will this server use DHCP? (Y/n): "
        read DHCP
        if [ -z "$DHCP" ]
           then
                DHCP=y
        fi
        if [ $DHCP == "n" ]
           then
                get_ipaddr
                get_netmask
                get_gateway
        fi
}

get_bonding()
{
        echo -n "Are the network interfaces on this server bonded? (y/N): "
        read BONDING
        if [ -z "$BONDING" ]
           then
                BONDING=n
        fi
        if [ $BONDING == "y" ]
           then
                get_bonding_name
        fi

}

get_bonding_name()
{
        echo -n "Enter bonded device name (default: bond0): "
        read BONDED_DEVICE
        if [ -z "$BONDED_DEVICE" ]
           then
                BONDED_DEVICE=bond0
        fi
}

get_ipaddr()
{
        echo -n "Enter the IP address: "
        read IPADDR
}

get_netmask()
{
        echo -n "Enter the subnet mask: "
        read NETMASK
}

get_gateway()
{
        echo -n "Enter the gateway address: "
        read GATEWAY
}

get_verify()
{
        echo " "
        echo "Please verify that the following information is correct: "
        echo " "
        echo "Hostname: $HOSTNAME"
        echo "Using DHCP: $DHCP"
        echo "Using bonding: $BONDING"
        if [ $BONDING == "y" ]
           then
                echo "Bonded device name: $BONDED_DEVICE"
        fi
        if [ $DHCP == "n" ]
           then
                echo "IP Address: $IPADDR"
                echo "Netmask: $NETMASK"
                echo "Gateway: $GATEWAY"
        fi
        echo " "
        echo -n "If this looks correct please type \"yes\" to continue: "
        read VERIFIED
        if [ -z "$VERIFIED" ]
           then
                VERIFIED=no
        fi
        if [ $VERIFIED != "yes" ]
           then
                echo "Looks like you screwed up. Please start the script again"
                exit 1
        fi
        if [ $VERIFIED == "yes" ]
           then
                create_backups
        fi
}

modify_networkfile()
{

        echo ""
        echo "Modifying the file $NETWORKFILE..."
        echo "NETWORKING=yes" > $NETWORKFILE
        echo "NETWORKING_IPV6=no" >> $NETWORKFILE
        echo "HOSTNAME=$HOSTNAME" >> $NETWORKFILE
        if [ $DHCP == "n" ]
           then
                echo "GATEWAY=$GATEWAY" >> $NETWORKFILE
        fi
}

modify_interface_files()
{
        echo ""
        echo "Modifying the network interface files in $NETCONFIGDIR..."
        if [ $DHCP == "y" ]
           then
                if [ $BONDING == "y" ]
                   then
                        echo "DEVICE=$BONDED_DEVICE" > $NETCONFIGFILE
                   else
                        echo "DEVICE=eth0" > $NETCONFIGFILE
                fi
                echo "BOOTPROTO=dhcp" >> $NETCONFIGFILE
                echo "ONBOOT=yes" >> $NETCONFIGFILE
                echo "DHCP_HOSTNAME=$HOSTNAME" >> $NETCONFIGFILE
        fi
        if [ $DHCP == "n" ]
           then
                if [ $BONDING == "y" ]
                   then
                        echo "DEVICE=$BONDED_DEVICE" > $NETCONFIGFILE
                   else
                        echo "DEVICE=eth0" > $NETCONFIGFILE
                fi
                echo "BOOTPROTO=static" >> $NETCONFIGFILE
                echo "ONBOOT=yes" >> $NETCONFIGFILE
                echo "TYPE=Ethernet" >> $NETCONFIGFILE
                echo "USERCTL=no" >> $NETCONFIGFILE
                echo "IPV6INIT=no" >> $NETCONFIGFILE
                echo "IPADDR=$IPADDR" >> $NETCONFIGFILE
                echo "NETMASK=$NETMASK" >> $NETCONFIGFILE

                cp /etc/resolv.conf.static /etc/resolv.conf
        fi
        if [ $BONDING == "y" ]
           then
                echo "DEVICE=eth0" > $NETCONFIGDIR/ifcfg-eth0
                echo "BOOTPROTO=none" >> $NETCONFIGDIR/ifcfg-eth0
                echo "ONBOOT=yes" >> $NETCONFIGDIR/ifcfg-eth0
                echo "USERCTL=no" >> $NETCONFIGDIR/ifcfg-eth0
                echo "MASTER=$BONDED_DEVICE" >> $NETCONFIGDIR/ifcfg-eth0
                echo "SLAVE=yes" >> $NETCONFIGDIR/ifcfg-eth0

                echo "DEVICE=eth1" > $NETCONFIGDIR/ifcfg-eth1
                echo "BOOTPROTO=none" >> $NETCONFIGDIR/ifcfg-eth1
                echo "ONBOOT=yes" >> $NETCONFIGDIR/ifcfg-eth1
                echo "USERCTL=no" >> $NETCONFIGDIR/ifcfg-eth1
                echo "MASTER=$BONDED_DEVICE" >> $NETCONFIGDIR/ifcfg-eth1
                echo "SLAVE=yes" >> $NETCONFIGDIR/ifcfg-eth1

                cp /etc/modprobe.conf.bonding /etc/modprobe.conf
        fi
        echo "Finished modifying the network interface files."

}

create_backups()
{
        #
        # Now let's define which network interface config file we need to modify
        #
        if [ $BONDING == "y" ]
           then
                NETCONFIGFILE="$NETCONFIGDIR/ifcfg-$BONDED_DEVICE"
           else
                NETCONFIGFILE="$NETCONFIGDIR/ifcfg-eth0"
        fi

        #
        # Let test to see if the following net config files exist and if so make a backup
        #
        if [ -e $NETCONFIGDIR/ifcfg-bond0 ]
           then
                echo "Backing up the file $NETCONFIGDIR/ifcfg-bond0 ..."
                cp $NETCONFIGDIR/ifcfg-bond0 $NETCONFIGDIR/ifcfg-bond0.bak
        fi
        if [ -e $NETCONFIGDIR/ifcfg-eth0 ]
           then
                echo "Backing up the file $NETCONFIGDIR/ifcfg-eth0 ..."
                cp $NETCONFIGDIR/ifcfg-eth0 $NETCONFIGDIR/ifcfg-eth0.bak
        fi
        if [ -e $NETCONFIGDIR/ifcfg-eth1 ]
           then
                echo "Backing up the file $NETCONFIGDIR/ifcfg-eth1 ..."
                cp $NETCONFIGDIR/ifcfg-eth1 $NETCONFIGDIR/ifcfg-eth1.bak
        fi

}

server_restart()
{
        echo " "
        echo "To finish the configuration you need to restart the server. Would you like to do that now? (y/N): "
        read RESTART
        if [ -z $RESTART ]
           then
                RESTART=n
        fi
        if [ $RESTART == "y" ]
           then
                echo "Restarting the server....."
                shutdown -fr now
                exit 0
           else
                echo "exiting....."
                exit 0
        fi
}

################### End of Global Functions ####################################################


#
# Let's start our script and ask for input
#
get_hostname
get_dhcp
get_bonding
get_verify

#
# Let's now modify the appropriate files now that we have our info
#
modify_networkfile
modify_interface_files
server_restart


exit 0

