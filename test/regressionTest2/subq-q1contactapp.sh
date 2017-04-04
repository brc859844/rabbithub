#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1contactapp"
AppName="my%20test%20app"

./subq_contactapp.sh $Vhost $Queue $Topic2 $Callback $User $Pass $AppName
