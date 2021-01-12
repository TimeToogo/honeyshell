#!/bin/bash

# Interpret first line of stdin as file key
read FILE_KEY

if [[ -z "$FILE_KEY" ]];
then
    echo "Socket did not send file name"
    exit 1
fi

if [[ ! "$FILE_KEY" =~ ^[a-z\.]{1,15}$ ]];
then
    echo "Socket sent invalid file name: $FILE_KEY"
    exit 1
fi

echo "Uploading $FILE_KEY data to s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/$FILE_KEY"
aws s3 cp --acl=public-read --cache-control max-age=31536000 - s3://$AWS_S3_LOGGING_BUCKET/$S3_KEY/$FILE_KEY <&0
