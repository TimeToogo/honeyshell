#!/bin/sh

USER=$1

if [[ -z "$USER" ]];
then
    echo "usage: $0 [username]"
    exit 1
fi

echo "Adding $USER insecurely..."
addgroup $USER
adduser -g "" -s /usr/bin/sudosh -G $USER -D $USER 
passwd -d $USER
echo "$USER ALL=($USER) NOPASSWD:ALL" >> /etc/sudoers
