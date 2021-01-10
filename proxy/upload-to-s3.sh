#!/bin/bash

echo "Uploading ttyout data to s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/ttyout"
aws s3 cp --acl=public-read --cache-control max-age=31536000 - s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/ttyout <&0
