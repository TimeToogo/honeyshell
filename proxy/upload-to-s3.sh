#!/bin/bash

echo "Uploading ttyout data to s3://$AWS_S3_LOGGING_BUCKET/$CONN_START_TIME/ttyout"
aws s3 cp --acl=public-read - s3://$AWS_S3_LOGGING_BUCKET/$CONN_START_TIME/ttyout <&0
