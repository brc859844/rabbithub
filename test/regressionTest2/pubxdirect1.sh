#!/bin/bash
## Publish a message to the xdirect 1 exchange with topic of blue
## see topic bindings for this exchange

source ./regressionTestVariables.sh

curl -v -d "test message for x direct" --header "x-correlation-id:1234321"  "http://$User:$Pass@localhost:15670/$Vhost/endpoint/x/xdirect1?hub.topic=blue&hub.persistmsg=true"

