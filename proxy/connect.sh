#!/bin/bash

# Handling incomming ssh connection script
# stdin = tcp - incoming from ssh client -> forward to ssh server
# stdout = tcp - incoming from ssh server -> forward to ssh client

set -e

LOG=$1

# Connection info
CONN_DATE="$(date -Iseconds | cut -d+ -f1 | tr ':' '-')"

# Allocate ports (TODO)
INBOUND_PORT_SSH=$((40000 + $$))
INBOUND_PORT_TTY=$((40001 + $$))

# Trigger lambda function to connect back to api
LAMBDA_PAYLOAD="{\
    \"host\": \"$CURRENT_IP\",\
    \"ssh_port\": \"$INBOUND_PORT_SSH\",\
    \"tty_port\": \"$INBOUND_PORT_TTY\"\
}"

# Relay the incoming tcp connection from the lambda function to stdio
echo "Listening to port $INBOUND_PORT_SSH" >> $LOG
socat TCP-LISTEN:$INBOUND_PORT_SSH STDIO >&1 <&0 &
SOCAT_SSH_PID=$!

# Write the ttyout to s3 log
echo "Uploading ttyout data on port $INBOUND_PORT_TTY to s3://$AWS_S3_LOGGING_BUCKET/$CONN_DATE/ttyout" >> $LOG
socat TCP-LISTEN:$INBOUND_PORT_TTY SYSTEM:"/run/upload-to-s3.sh" &
SOCAT_TTY_PID=$!

echo "Invoking lambda function" >> $LOG
if [[ -z "$AWS_LAMBDA_RIE_API" ]];
then
    (aws lambda invoke --function-name $AWS_LAMBDA_FUNCTION_NAME --payload "$LAMBDA_PAYLOAD" >> $LOG 2>&1 &)
else
    (curl -sSf -XPOST http://$AWS_LAMBDA_RIE_API/2015-03-31/functions/function/invocations -d "$LAMBDA_PAYLOAD" >> $LOG 2>&1 &)
fi
LAMBDA_INVOKE_PID=$!

# Wait for connections to finish
echo "Waiting for connection to finish" >> $LOG
wait $SOCAT_SSH_PID
if [[ -d "/proc/$SOCAT_TTY_PID" ]];
then
    kill $SOCAT_TTY_PID || true
fi

echo "Finished" >> $LOG

