#!/bin/bash
## calls delSubq.sh to delete a particular subscriber to a queue
## regressionTestVariables supplies User, Pass, Vhost

source ./regressionTestVariables.sh

Queue=q1
Callback="http://localhost:8999/rabbithub/s1"
Topic="testq1"

./delSubq.sh $Vhost $Queue $Topic $Callback $User $Pass

