#!/bin/bash

aws s3 cp - s3://$AWS_S3_LOGGING_BUCKET/$CONN_DATE/ttyout <&0