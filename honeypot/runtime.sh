#!/bin/sh

set -e

if [[ -z "$PROXY_HOST" ]];
then
    echo "PROXY_HOST env var must be defined"
    exit 1
fi

if [[ -z "$PROXY_HOST" ]];
then
    echo "PROXY_HOST env var must be defined"
    exit 1
fi

if [[ -z "$PROXY_TTY_PORT" ]];
then
    echo "PROXY_TTY_PORT env var must be defined"
    exit 1
fi


LOG_DIR=/var/log/sudo-io/session

stream_file_to_proxy() {
    local FILE=$1
    echo "Redirecting $FILE to $PROXY_HOST:$PROXY_TTY_PORT"
    { echo "$(basename "$FILE")"; tail -f -n +1 "$FILE"; } | socat -u STDIN,ignoreeof TCP:$PROXY_HOST:$PROXY_TTY_PORT &
    SOCAT_TTY_PID=$!
    trap "sleep 30 && kill $SOCAT_TTY_PID >/dev/null 2>&1 || true" EXIT
}

inotifywait $LOG_DIR -m -e create | while read DIR ACTION FILE_NAME; 
    do
        FILE="$DIR$FILE_NAME"
        stream_file_to_proxy $FILE
    done &

# Wait for session to authenticate (will start logging to $LOG_DIR)
echo "Waiting for logging to $LOG_DIR"
# Allow 10 seconds for ssh session to begin
timeout 10 inotifywait $LOG_DIR -e create -e open &
WAIT_FOR_CONNECTION_PID=$!

# Connect to proxy ssh relay port
echo "Relaying sshd to $PROXY_HOST:$PROXY_SSH_PORT"
timeout $CONN_TIMEOUT_S socat TCP:localhost:22 TCP:$PROXY_HOST:$PROXY_SSH_PORT &
SOCAT_SSH_PID=$!
# Ensure connection is killed when script ends
trap "kill $SOCAT_SSH_PID >/dev/null 2>&1 || true" EXIT

echo "Waiting for connection to be made..."
wait $WAIT_FOR_CONNECTION_PID
echo "Connection made"

echo "Waiting for session to complete..."
wait $SOCAT_SSH_PID
echo "Session finished..."

# Allow sudo buffers to be flushed and logs to be sent
sleep 3
