#!/bin/bash

set -e

# Handling incomming ssh connection script
# stdin = tcp - incoming from ssh client -> forward to ssh server
# stdout = tcp - incoming from ssh server -> forward to ssh client

LOG=$1
export AWS_PAGER=""

exec 3<&0 4>&1 # reassign tcp io to fd 3 & 4
exec 1>$LOG 2>$LOG # send stdin/stderr to parent process stdout

echo "Received connection from $SOCAT_PEERADDR:$SOCAT_PEERPORT"

# Connection info
CONN_START_TIME="$(date -Iseconds | cut -d+ -f1 | tr ':' '_')Z"

# Use different between large number and timestamp to ensure a decreasing S3 prefix
# This allows the sorting of ListObjectsV2 to return most recent sessions first
export S3_KEY="$(printf %016d $(((2 ** 40) - $(date +%s%))))-$CONN_START_TIME"

# Relay the incoming tcp connection from the honeypot to stdio (tcp from ssh client)
timeout $CONN_TIMEOUT_S socat TCP-LISTEN:0 STDIO <&3 >&4 &
SOCAT_SSH_PID=$!
# Ensure socket closed when script exits
trap "kill $SOCAT_SSH_PID >/dev/null 2>&1 || true" EXIT

# Write the ttyout to s3 log
socat -u TCP-LISTEN:0 SYSTEM:"/run/upload-to-s3.sh > $LOG 2>&1" &
SOCAT_TTY_PID=$!
trap "kill $SOCAT_TTY_PID >/dev/null 2>&1 || true" EXIT

# Allow socat to bind
while [[ -z "$INBOUND_PORT_SSH" ]] || [[ -z "$INBOUND_PORT_TTY" ]]
do
    sleep 0.1
    INBOUND_PORT_SSH="$(netstat -ntlp | grep $SOCAT_SSH_PID | head -n1 | awk '{print $4}' | cut -d':' -f2)"
    INBOUND_PORT_TTY="$(netstat -ntlp | grep $SOCAT_TTY_PID | head -n1 | awk '{print $4}' | cut -d':' -f2)"
done

echo "Listening on port $INBOUND_PORT_SSH for ssh proxy"
echo "Listening on port $INBOUND_PORT_TTY for tty logging"

echo "Running honeypot container..."
if [[ -z "$LOCAL_CONTAINER" ]];
then
    ECS_TASK_DATA="$(aws ecs run-task \
        --cluster $HONEYPOT_CLUSTER \
        --task-definition $HONEYPOT_TASK_DEFINITION \
        --overrides "{\
            \"containerOverrides\": [\
                {\
                    \"name\": \"$HONEYPOT_CONTAINER\",\
                    \"environment\": [\
                        {\"name\": \"CONN_TIMEOUT_S\", \"value\": \"$CONN_TIMEOUT_S\"},\
                        {\"name\": \"PROXY_HOST\", \"value\": \"$CURRENT_IP\"},\
                        {\"name\": \"PROXY_SSH_PORT\", \"value\": \"$INBOUND_PORT_SSH\"},\
                        {\"name\": \"PROXY_TTY_PORT\", \"value\": \"$INBOUND_PORT_TTY\"}\
                    ]\
                }\
            ]\
        }")"

    echo "Started ECS task: $ECS_TASK_DATA"
    ECS_TASK_ARN="$(echo "$ECS_TASK_DATA" | jq -r '.tasks[0].taskArn')"
    echo "Task ARN: $ECS_TASK_ARN"

    stop_container() {
        echo "Stopping ECS task $ECS_TASK_ARN"
        aws ecs stop-task \
            --cluster $HONEYPOT_CLUSTER \
            --task $ECS_TASK_ARN
    }
else
    CONTAINER_ID="$(docker run -d \
        -e CONN_TIMEOUT_S=300 \
        -e PROXY_HOST=$CURRENT_IP \
        -e PROXY_SSH_PORT=$INBOUND_PORT_SSH \
        -e PROXY_TTY_PORT=$INBOUND_PORT_TTY \
        --network $DOCKER_NETWORK \
        $HONEYPOT_IMAGE_NAME \
    )"
    echo "Started honeypot container: $CONTAINER_ID"

    stop_container() {
        echo "Killing honeypot container $CONTIAINER_ID..."
        docker kill $CONTAINER_ID
    }
fi


trap "stop_container" EXIT

# Wait for connections to finish
echo "Waiting for connection to finish"
wait $SOCAT_SSH_PID

CONN_END_TIME="$(date -Iseconds | cut -d+ -f1 | tr ':' '-')Z"
echo "Retreiving ip info for $SOCAT_PEERADDR"
IP_INFO="$(curl -sS -H "Authorization: Bearer $IP_INFO_API_TOKEN" https://ipinfo.io/$SOCAT_PEERADDR)"
IP_INFO=${IP_INFO:='{}'}

MANIFEST_PAYLOAD="{\
    \"peer_ip\": \"$SOCAT_PEERADDR\",\
    \"peer_port\": \"$SOCAT_PEERPORT\",\
    \"time_start\": \"$CONN_START_TIME\",\
    \"time_end\": \"$CONN_END_TIME\",\
    \"ip_info\": $IP_INFO
}"

echo "Uploading manifest to s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/manifest.json"
echo "$MANIFEST_PAYLOAD" | aws s3 cp --acl=public-read - s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/manifest.json

echo "Finished"

