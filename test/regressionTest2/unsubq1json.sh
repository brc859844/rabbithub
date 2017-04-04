#!/bin/bash
## unsubscribes a subscriber from a queue using the json format (deactivate)

source ./regressionTestVariables.sh

curl -vd '{
	"hub": {
		"callback": "'"$Callback"'",
		"topic": "testq1",
		"mode": "unsubscribe",
		"verify": "sync"
	}
}' --header "content-type:application/json"  http://$User:$Pass@localhost:15670/$Vhost/subscribe/q/q1

