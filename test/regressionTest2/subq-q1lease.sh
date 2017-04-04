#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1lease"
Lease=86400

./subq_lease.sh $Vhost $Queue $Topic2 $Callback $User $Pass $Lease
