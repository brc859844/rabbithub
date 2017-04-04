#!/bin/bash
## deletes a subscriber to a queue
## $1 - vhost
## $2 - queue name
## $3 - topic
## $4 - callback url
## $5 - rabbitmq user
## $6 - rabbitmq password
## $7 - resource type (q, x)

## this script is used by delBatch.sh

curl -v  -XDELETE "http://$5:$6@localhost:15670/$1/subscribe/$7/$2?hub.mode=subscribe&hub.callback=$4&hub.topic=$3&hub.verify=sync&hub.lease_seconds=2000000"



