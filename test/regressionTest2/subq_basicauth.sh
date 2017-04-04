#!/bin/bash
## Create a subscriber with basic auth value for subscriber
## $1 - vhost
## $2 - queue name
## $3 - topic
## $4 - callback url
## $5 - rabbitmq user
## $6 - rabbitmq password
## $7 - basich auth value

curl -vd "hub.mode=subscribe&hub.callback=$4&hub.topic=$3&hub.verify=sync&hub.basic_auth=$7" http://$5:$6@localhost:15670/$1/subscribe/q/$2

