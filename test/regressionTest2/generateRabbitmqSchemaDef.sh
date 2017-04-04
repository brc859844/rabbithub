#!/bin/bash
## This script will use the regressionTestVariables.sh values to 
## generate a json file in the rabbitmq definitions format to 
## create a vhost and a set of exchanges, queues and bindings
## to be used for a series of tests
## The file RabbitHubTestVhost-$Vhost.json will be created
## NOTE:
## User/Pass must be rabbithub/rabbithub since the password has is already 
## set.  To use a different user/pass create in rabbitmq, export and copy user
## to this file

source ./regressionTestVariables.sh

Json='{
    "users":[{"name":"rabbithub",
        "password_hash":"Pmql2dC0pTnWY42NEoiojP4r159WLhbAY1CBVn0ZQyJ0GSVS",
        "hashing_algorithm":"rabbit_password_hashing_sha256",
        "tags":"administrator,rabbithub_admin"
    }],
    "vhosts": [{
		"name": "'"$Vhost"'"
	}],
	"permissions": [{
		"user": "rabbithub",
		"vhost": "'"$Vhost"'",
		"configure": ".*",
		"write": ".*",
		"read": ".*"
	}],
	"queues": [{
		"name": "q1",
		"vhost": "'"$Vhost"'",
		"durable": true,
		"auto_delete": false,
		"arguments": {}
	}, {
		"name": "q2",
		"vhost": "'"$Vhost"'",
		"durable": true,
		"auto_delete": false,
		"arguments": {}
	}, {
		"name": "q3",
		"vhost": "'"$Vhost"'",
		"durable": true,
		"auto_delete": false,
		"arguments": {}
	}, {
		"name": "q4",
		"vhost": "'"$Vhost"'",
		"durable": true,
		"auto_delete": false,
		"arguments": {}
	} ],
	"exchanges": [{
		"name": "xfanout1",
		"vhost": "'"$Vhost"'",
		"type": "fanout",
		"durable": true,
		"auto_delete": false,
		"internal": false,
		"arguments": {}
	}, {
		"name": "xheaders1",
		"vhost": "'"$Vhost"'",
		"type": "headers",
		"durable": true,
		"auto_delete": false,
		"internal": false,
		"arguments": {}
	}, {
		"name": "xtopic1",
		"vhost": "'"$Vhost"'",
		"type": "headers",
		"durable": true,
		"auto_delete": false,
		"internal": false,
		"arguments": {}
	}, {
		"name": "xdirect1",
		"vhost": "'"$Vhost"'",
		"type": "headers",
		"durable": true,
		"auto_delete": false,
		"internal": false,
		"arguments": {}
	}],
	"bindings": [{
		"source": "xfanout1",
		"vhost": "'"$Vhost"'",
		"destination": "q1",
		"destination_type": "queue",
		"routing_key": "",
		"arguments": {}
	}, {
		"source": "xheaders1",
		"vhost": "'"$Vhost"'",
		"destination": "q2",
		"destination_type": "queue",
		"routing_key": "",
		"arguments": {
			"key1": "A",
			"key2": "B",
			"x-match": "any"
		}
	}, {
		"source": "xtopic1",
		"vhost": "'"$Vhost"'",
		"destination": "q3",
		"destination_type": "queue",
		"routing_key": "#.c",
		"arguments": {}
	}, {
		"source": "xdirect1",
		"vhost": "'"$Vhost"'",
		"destination": "q4",
		"destination_type": "queue",
		"routing_key": "blue",
		"arguments": {}
	}]
}'


echo $Json > RabbitHubTestVhost-$Vhost.json

