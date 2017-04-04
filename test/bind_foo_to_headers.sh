#!/bin/bash

#  This script uses the management api (this is not a rabbithub api) to bind queue foo to amq.headers with arguments
#    keya:	valueA
#    keyb:	valueB
#    x-match:	any 
#  {"routing_key":"my_routing_key","arguments":{}}

#  /api/bindings/vhost/e/exchange/q/queue

#    http://localhost:15672/api/bindings/vhost/e/amq.headers/q/foo


curl -H 'Content-Type: application/json' -X POST -d '{"arguments":{"keya":"valueA","keyb":"valueB","x-match":"any"}}' http://guest:guest@localhost:15672/api/bindings/%2F/e/amq.headers/q/foo


## curl 'http://localhost:15672/api/bindings/%2F/e/amq.headers/q/foo' -H 'Host: localhost:15672' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Content-Type: application/json' -H 'Authorization: Basic Z3Vlc3Q6Z3Vlc3Q=' -H 'Referer: http://localhost:15672/' -H 'Content-Length: 142' -H 'Connection: keep-alive'
# '{"vhost":"/","source":"amq.headers","destination_type":"q","destination":"foo","routing_key":"","arguments":{"x-match":"any","keya":"valueA"}}'
