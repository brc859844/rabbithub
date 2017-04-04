#!/bin/bash
## Publish message to the xheaders1 exchange with header values of 
##  key1 = A,key2 = B
## queue was bound to this exchange with "key1": "A", "key2": "B", "x-match": "any" 

source ./regressionTestVariables.sh

curl -v -d "test message for x header" --header "x-correlation-id:1234321"  --header "x-rabbithub-msg_header:key1 = A,key2 = B" "http://$User:$Pass@localhost:15670/$Vhost/endpoint/x/xheaders1?hub.topic=testheader&hub.persistmsg=true"

