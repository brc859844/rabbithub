#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1contactall"
AppName="my%20est%20app%202"
Name='my%20name'
Phone="111-111-1111"
Email="me@mail.com"
Desc='my%20test%20app%20description'

./subq_contactall.sh $Vhost $Queue $Topic2 $Callback $User $Pass $AppName $Name $Phone $Email $Desc
