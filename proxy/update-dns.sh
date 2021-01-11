#!/bin/bash

set -e

HOSTED_ZONE_ID=$1
DOMAIN_NAME=$2
CURRENT_IP=$3

if [[ -z "$HOSTED_ZONE_ID" ]] || [[ -z "$DOMAIN_NAME" ]] || [[ -z "$CURRENT_IP" ]];
then
    echo "usage $0 [hosted zone id] [domain name] [current ip]"
    exit 1
fi

echo "Updating domain A record $DOMAIN_NAME (hosted zone $HOSTED_ZONE_ID) to $CURRENT_IP"

AWS_PAGER="" aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch "{ \
        \"Comment\": \"Updating record to current IP\", \
        \"Changes\": [{ \
            \"Action\": \"UPSERT\", \
            \"ResourceRecordSet\": { \
                \"Name\": \"$DOMAIN_NAME\", \
                \"Type\": \"A\", \
                \"TTL\": 300, \
                \"ResourceRecords\": [{ \"Value\": \"$CURRENT_IP\"}] \
            } \
        }] \
    }"

echo "Record updated!"
