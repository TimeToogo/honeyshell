#!/bin/bash

set -e

HEADERS="$(mktemp)"
# Get an event. The HTTP request will block until one is received
EVENT_DATA=$(curl -sS -LD "$HEADERS" -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")

# Extract request ID by scraping response headers received above
REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

echo "Received event: $EVENT_DATA"

# Parse request params
echo "Parsing event data..."
PROXY_HOST=$(echo "$EVENT_DATA" | jq -r .host)
PROXY_SSH_PORT=$(echo "$EVENT_DATA" | jq -r .ssh_port)
PROXY_TTY_PORT=$(echo "$EVENT_DATA" | jq -r .tty_port)

# Connect to proxy ssh port
echo "Relaying sshd to $PROXY_HOST:$PROXY_SSH_PORT"
socat TCP:localhost:22 TCP:$PROXY_HOST:$PROXY_SSH_PORT &
SOCAT_SSH_PID=$!

LOG_DIR=/var/log/sudo-io/session
# Wait for session to authenticate (will start logging to $LOG_DIR)
echo "Waiting for logging to $LOG_DIR"
touch $LOG_DIR/ttyout
inotifywait  $LOG_DIR/ttyout -e open

echo "Redirecting $LOG_DIR/ttyout to $PROXY_HOST:$PROXY_TTY_PORT"
socat FILE:$LOG_DIR/ttyout,ignoreeof TCP:$PROXY_HOST:$PROXY_TTY_PORT &
SOCAT_TTY_PID=$!

echo "Waiting for session to complete..."
tail --pid=$SOCAT_SSH_PID -f /dev/null
echo "Session finished..."

if [[ -d "/proc/$SOCAT_TTY_PID" ]];
then
    kill $SOCAT_TTY_PID || true
fi

# Send the response
curl -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response"

# Force instance to rebuild
exit 1