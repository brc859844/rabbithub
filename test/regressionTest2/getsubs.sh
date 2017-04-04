#!/bin/bash
## Get all subscribers in json format
source ./regressionTestVariables.sh

curl --request GET http://$User:$Pass@localhost:15670/subscriptions
