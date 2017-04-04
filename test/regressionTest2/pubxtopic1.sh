#!/bin/bash
## Publish message to exchange xtopic1 with a topic of a.b.c
## see bindings for this topic

source ./regressionTestVariables.sh

curl -v -d "test message for x topic" --header "x-correlation-id:1234321"  "http://$User:$Pass@localhost:15670/$Vhost/endpoint/x/xtopic1?hub.topic=a.b.c&hub.persistmsg=true"

