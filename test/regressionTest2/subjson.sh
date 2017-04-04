#!/bin/bash
## Create subscriber for queue q1 with json message
source ./regressionTestVariables.sh

curl -vd '{
	"hub": {
		"callback": "'"$Callback"'",
		"topic": "testsubjson",
		"mode": "subscribe",
		"verify": "sync",
	}
}' --header "content-type:application/json"  http://$User:$Pass@localhost:15670/$Vhost/subscribe/q/q1

