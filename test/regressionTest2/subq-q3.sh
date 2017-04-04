#!/bin/bash
source ./regressionTestVariables.sh

Queue=q3
Topic="a.b.c"

./subq.sh $Vhost $Queue $Topic $Callback $User $Pass

