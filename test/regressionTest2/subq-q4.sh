#!/bin/bash
source ./regressionTestVariables.sh

Queue=q4
Topic="blue"

./subq.sh $Vhost $Queue $Topic $Callback $User $Pass

