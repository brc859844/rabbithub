#!/bin/bash
## create a subscriber to a queue with lease
## $1 - vhost
## $2 - queue name
## $3 - topic
## $4 - callback url
## $5 - rabbitmq user
## $6 - rabbitmq password
## $7 - lease in seconds

curl -vd "hub.mode=subscribe&hub.callback=$4&hub.topic=$3&hub.verify=sync&hub.lease_seconds=$7" http://$5:$6@localhost:15670/$1/subscribe/q/$2

