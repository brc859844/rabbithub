#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1hamode-1"
HAMode=1

./subq_hamode.sh $Vhost $Queue $Topic2 $Callback $User $Pass $HAMode
