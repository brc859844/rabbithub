#!/bin/bash
## get 1 subscriber as defined below

source ./regressionTestVariables.sh

Queue=q2
Callback="http://localhost:8999/rabbithub/s1"
Topic="testq2"
Type="q"

./get1Sub.sh $Vhost $Type $Queue $Topic $Callback $User $Pass

