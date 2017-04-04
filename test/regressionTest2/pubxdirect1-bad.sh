#!/bin/bash
## Publish a message to the xdirect 1 exchange with keyword 'bad' in body, 
## for testing the subscriber has been configured to return a 400 when it 
## finds the work 'bad' in the message body.  If your subscriber does not have
## this capability it should work as pubxdirect1.sh

source ./regressionTestVariables.sh

curl -v -d "bad test message for x direct" --header "x-correlation-id:1234321"  "http://$User:$Pass@localhost:15670/$Vhost/endpoint/x/xdirect1?hub.topic=blue&hub.persistmsg=true"

