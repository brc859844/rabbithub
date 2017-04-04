#!/bin/bash
## publish a message to exchange xfanout1 with correlation-id, this id will be passed
## on to the subscriber

source ./regressionTestVariables.sh

curl -v -d "test message for x fanout" --header "x-correlation-id:1234321"  "http://$User:$Pass@localhost:15670/$Vhost/endpoint/x/xfanout1?hub.topic=testfanout&hub.persistmsg=true"

