#!/bin/bash
## import rabbitmq json definitions file into rabbitmq
## $1 = rabbitmq.json file name

source ./regressionTestVariables.sh

curl -X POST -vd @$1 -H "content-type: application/json" http://$User:$Pass@localhost:15672/api/definitions
