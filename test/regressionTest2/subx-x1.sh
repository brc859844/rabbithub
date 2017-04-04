#!/bin/bash
source ./regressionTestVariables.sh

Exchange=xfanout1
Topic="testx1"

./subx.sh $Vhost $Exchange $Topic $Callback $User $Pass

