#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Callback="http://localhost:8999/rabbithub/s1"
Topic="testq1"

./subq.sh $Vhost $Queue $Topic $Callback $User $Pass

