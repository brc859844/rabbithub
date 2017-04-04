#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1maxtps2"
MaxTps=2

./subq_maxtps.sh $Vhost $Queue $Topic2 $Callback $User $Pass $MaxTps
