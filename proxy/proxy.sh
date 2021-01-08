#!/bin/bash

set -e

echo "Starting ssh proxy server..."

if [[ -z "$LISTEN_PORT" ]];
then
    echo "Missing LISTEN_PORT var..."
    exit 1
fi

if [[ -z "$AWS_S3_LOGGING_BUCKET" ]];
then
    echo "Missing AWS_S3_LOGGING_BUCKET var..."
    exit 1
fi

if [[ -z "$CURRENT_IP" ]];
then
    export CURRENT_IP="$(curl -sSf https://ipinfo.io/ip)"
fi

echo "Current external IP: $CURRENT_IP"
echo "Starting ssh proxy server on port $LISTEN_PORT..."
mkfifo stdout.sock
tail -f stdout.sock >&1 &
while true;
do
    socat TCP-LISTEN:$LISTEN_PORT,reuseaddr,fork SYSTEM:"/run/connect.sh stdout.sock"
done