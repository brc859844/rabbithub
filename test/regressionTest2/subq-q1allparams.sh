#!/bin/bash
source ./regressionTestVariables.sh

Queue=q1
Topic2="testq1allparams"
AppName="my%20est%20app%202"
Name='my%20name'
Phone="111-111-1111"
Email="me@mail.com"
Desc='my%20test%20app%20description'
BasicAuth="base64encodedstring"
HAMode="all"
MaxTps=2
Lease=86400



./subq_allparams.sh $Vhost $Queue $Topic2 $Callback $User $Pass $AppName $Name $Phone $Email $Desc $BasicAuth $HAMode $MaxTps $Lease
