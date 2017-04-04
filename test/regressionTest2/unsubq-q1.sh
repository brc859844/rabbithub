#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic="testq1"

./unsubq.sh $Vhost $Queue $Topic $Callback $User $Pass

