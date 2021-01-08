#!/bin/bash

if [[ ! -z "$RUNTIME_EMULATOR" ]];
then
    mkdir -p /aws-lambda-rie
    curl -Lo /aws-lambda-rie/rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie
    chmod +x /aws-lambda-rie/rie
fi