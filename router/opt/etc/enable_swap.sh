#!/bin/sh

if [ ! -f /tmp/mnt/sda1/myswap.swp ]; then
    #create a 256MB swap file ("count" is in Kilobytes)
    echo "This step only need be run once when you first deploy."
    echo "it's maybe [0m[33mvery slow[0m depend on your USB stick speed, please wait a while."

    dd if=/dev/zero of=/tmp/mnt/sda1/myswap.swp bs=1k count=1048576

    #set up the swap file
    mkswap /tmp/mnt/sda1/myswap.swp
fi

#enable swap
swapon /tmp/mnt/sda1/myswap.swp

#check if swap is on
free
