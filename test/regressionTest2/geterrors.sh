#!/bin/bash
## Get all errors for all subscribers

source ./regressionTestVariables.sh

curl --request GET http://$User:$Pass@localhost:15670/subscriptions/errors
