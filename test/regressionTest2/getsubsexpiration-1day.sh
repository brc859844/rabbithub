#!/bin/bash
## Get all subscribers that have an expiration date within 1 day

source ./regressionTestVariables.sh

curl --request GET http://$User:$Pass@localhost:15670/subscriptions?hub.expires=1
