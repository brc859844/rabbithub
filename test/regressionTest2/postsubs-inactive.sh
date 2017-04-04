#!/bin/bash
## Create a subscription via the batch interface as an inactive subscriber

source ./regressionTestVariables.sh

curl --write-out %{http_code}  -vd '{
	"subscriptions": [{
		"vhost": "rhtest",
		"resource_type": "queue",
		"resource_name": "q4",
		"topic": "testbatch",
		"callback": "http://localhost:8999/rabbithub/s1",
		"lease_seconds": 2000000,
		"ha_mode": "all",
		"status": "inactive",
		"maxtps": 5,
		"outbound_auth": {
			"auth_type": "basic_auth",
			"auth_config": "Ym9ubmllOmJhcmtlcg=="
		},
		"contact": {
			"app_name": "my test app 2",
			"contact_name": "my name",
			"phone": "111-111-1111",
			"email": "me@mail.com",
			"description": "my test app description"
		}
	}]
  }' --header "content-type:application/json" http://$User:$Pass@localhost:15670/subscriptions

