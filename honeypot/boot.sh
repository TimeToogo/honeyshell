#!/bin/bash

set -e

echo "Starting sshd server..."
ssh-keygen -A
/usr/sbin/sshd

if [[ -d /aws-lambda-rie ]];
then
    echo "Running with lambda runtime emulator..."
    /aws-lambda-rie/rie /bin/sh /run/runtime.sh
else
    /run/runtime.sh
fi