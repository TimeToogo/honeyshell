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

if [[ ! -z "$HEALTH_CHECK_PORT" ]];
then
    echo "Will respond to health checks on port $HEALTH_CHECK_PORT"
    socat TCP-LISTEN:$HEALTH_CHECK_PORT,reuseaddr,fork SYSTEM:"echo 'ok'" &
    HEALTH_CHECK_PID=$!
    trap "kill $HEALTH_CHECK_PID" EXIT
fi

echo "Current external IP: $CURRENT_IP"

if [[ ! -z "$HOSTED_ZONE_ID" ]] && [[ ! -z "$DOMAIN_NAME" ]];
then
    /run/update-dns.sh $HOSTED_ZONE_ID $DOMAIN_NAME $CURRENT_IP
fi

while true;
do
    echo "Starting ssh proxy server on port $LISTEN_PORT..."
    socat TCP-LISTEN:$LISTEN_PORT,reuseaddr,fork,pktinfo SYSTEM:"/run/connect.sh /proc/$$/fd/1"
    echo "socat exited with status $?"
done