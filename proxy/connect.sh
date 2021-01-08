#!/bin/bash

set -e

# Handling incomming ssh connection script
# stdin = tcp - incoming from ssh client -> forward to ssh server
# stdout = tcp - incoming from ssh server -> forward to ssh client

LOG=$1

exec 3<&0 4>&1 # reassign tcp io to fd 3 & 4
exec 1>$LOG 2>$LOG # send stdin/stderr to parent process stdout

# Connection info
CONN_DATE="$(date -Iseconds | cut -d+ -f1 | tr ':' '-')"

# Relay the incoming tcp connection from the lambda function to stdio
echo "Listening to port $INBOUND_PORT_SSH"
timeout $CONN_TIMEOUT_S socat TCP-LISTEN:0 STDIO <&3 >&4 &
SOCAT_SSH_PID=$!
# Ensure socket closed when script exits
trap "kill $SOCAT_SSH_PID >/dev/null 2>&1 || true" EXIT

# Write the ttyout to s3 log
echo "Uploading ttyout data on port $INBOUND_PORT_TTY to s3://$AWS_S3_LOGGING_BUCKET/$CONN_DATE/ttyout"
socat TCP-LISTEN:0 SYSTEM:"/run/upload-to-s3.sh" &
SOCAT_TTY_PID=$!
trap "kill $SOCAT_TTY_PID >/dev/null 2>&1 || true" EXIT

# Allow socat to bind
while [ -z "$INBOUND_PORT_SSH" ] || [ -z "$INBOUND_PORT_TTY "]
do
    sleep 0.1
    INBOUND_PORT_SSH="$(netstat -ntlp | grep $SOCAT_SSH_PID | head -n1 | awk '{print $4}' | cut -d':' -f2)"
    INBOUND_PORT_TTY="$(netstat -ntlp | grep $SOCAT_TTY_PID | head -n1 | awk '{print $4}' | cut -d':' -f2)"
done

echo "Listening on port $INBOUND_PORT_SSH for ssh proxy"
echo "Listening on port $INBOUND_PORT_TTY for tty logging"

# Trigger lambda function to connect back to api
LAMBDA_PAYLOAD="{\
    \"host\": \"$CURRENT_IP\",\
    \"ssh_port\": \"$INBOUND_PORT_SSH\",\
    \"tty_port\": \"$INBOUND_PORT_TTY\"\
}"

echo "Invoking lambda function"
if [[ -z "$AWS_LAMBDA_RIE_API" ]];
then
    aws lambda invoke --function-name $AWS_LAMBDA_FUNCTION_NAME --payload "$LAMBDA_PAYLOAD" &
else
    curl -sSf -XPOST http://$AWS_LAMBDA_RIE_API/2015-03-31/functions/function/invocations -d "$LAMBDA_PAYLOAD" &
fi
LAMBDA_INVOKE_PID=$!

# Wait for connections to finish
echo "Waiting for connection to finish"
wait $SOCAT_SSH_PID

echo "Finished"

