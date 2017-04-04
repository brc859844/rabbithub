#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1basicauth"
BasicAuth="base64encodedstring"

./subq_basicauth.sh $Vhost $Queue $Topic2 $Callback $User $Pass $BasicAuth
