#!/bin/bash

set -e

echo "Starting sshd server..."
/usr/sbin/sshd

/run/runtime.sh