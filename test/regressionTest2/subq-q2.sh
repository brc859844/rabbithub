#!/bin/bash
source ./regressionTestVariables.sh

Queue=q2
Topic="testq2"

./subq.sh $Vhost $Queue $Topic $Callback $User $Pass

