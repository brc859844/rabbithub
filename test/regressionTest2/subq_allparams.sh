#!/bin/bash
## create a subscriber to a queue with all parameters
## $1 - vhost
## $2 - queue name
## $3 - topic
## $4 - callback url
## $5 - rabbitmq user
## $6 - rabbitmq password
## $7 - application name
## $8 - contact name
## $9 - phone 
## $10 - email
## $11 - description
## $12 - basich auth value
## $13 - ha mode
## $14 - max tps value
## $15 - lease in seconds

curl -vd "hub.mode=subscribe&hub.callback=$4&hub.topic=$3&hub.verify=sync&hub.app_name=$7&hub.contact_name=$8&hub.phone=$9&hub.email=${10}&hub.description=${11}&hub.basic_auth=${12}&hub.ha_mode=${13}&hub.max_tps=${14}&hub.lease_seconds=${15}" http://$5:$6@localhost:15670/$1/subscribe/q/$2

