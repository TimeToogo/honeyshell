#!/bin/bash

FILE_KEY=$1

if [[ -z "$FILE_KEY" ]];
then 
    echo "usage: $0 [file key]"
    exit 1
fi

echo "Uploading $FILE_KEY data to s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/$FILE_KEY"
aws s3 cp --acl=public-read --cache-control max-age=31536000 - s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/$FILE_KEY <&0
