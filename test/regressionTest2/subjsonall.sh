#!/bin/bash
## Create subscriber for queue q1 with json message body with more options.

source ./regressionTestVariables.sh

curl -vd '{
	"hub": {
		"callback": "'"$Callback"'",
		"topic": "testsubjsonall",
		"lease_seconds": 1234,
		"mode": "subscribe",
		"verify": "sync",
		"max_tps": 3,
		"ha_mode": "all",
		"basic_auth": "base64str",
		"contact": {
			"app_name": "My App Name",
			"description": "this is my silly app"
		}
	}
}' --header "content-type:application/json"  http://$User:$Pass@localhost:15670/$Vhost/subscribe/q/q1

