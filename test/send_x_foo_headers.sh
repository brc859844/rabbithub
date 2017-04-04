#!/bin/bash

#  This script posts message past in on command line to exchange amq.headers with custom rabbithub http header value 
#   which is converted to rabbitmq message headers
#
#  Prerequisite:  run script create_q.sh foo
#                 run bind_foo_to_headers.sh 

curl -v -d "$1" --header "x-rabbithub-msg_header:keya = valueA,keyb = valueB" http://guest:guest@localhost:15670/endpoint/x/amq.headers
