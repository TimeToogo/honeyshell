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

if [[ -z "$PROXY_TIM_PORT" ]];
then
    echo "PROXY_TIM_PORT env var must be defined"
    exit 1
fi

# Connect to proxy ssh relay port
echo "Relaying sshd to $PROXY_HOST:$PROXY_SSH_PORT"
timeout $CONN_TIMEOUT_S socat TCP:localhost:22 TCP:$PROXY_HOST:$PROXY_SSH_PORT &
SOCAT_SSH_PID=$!
# Ensure connection is killed when script ends
trap "kill $SOCAT_SSH_PID >/dev/null 2>&1 || true" EXIT

LOG_DIR=/var/log/sudo-io/session
# Wait for session to authenticate (will start logging to $LOG_DIR)
echo "Waiting for logging to $LOG_DIR"
touch $LOG_DIR/ttyout
touch $LOG_DIR/timing
# Allow 10 seconds for ssh session to begin
timeout 10 inotifywait $LOG_DIR/ttyout -e open

echo "Redirecting $LOG_DIR/ttyout to $PROXY_HOST:$PROXY_TTY_PORT"
socat -u FILE:$LOG_DIR/ttyout,ignoreeof TCP:$PROXY_HOST:$PROXY_TTY_PORT &
SOCAT_TTY_PID=$!
trap "sleep 30 && kill $SOCAT_TTY_PID >/dev/null 2>&1 || true" EXIT

socat -u FILE:$LOG_DIR/timing,ignoreeof TCP:$PROXY_HOST:$PROXY_TIM_PORT &
SOCAT_TIM_PID=$!
trap "sleep 30 && kill $SOCAT_TIM_PID >/dev/null 2>&1 || true" EXIT

echo "Waiting for session to complete..."
wait $SOCAT_SSH_PID
echo "Session finished..."
