#!/bin/bash
## Delete a batch of subscribers
## $1 is the output file from getsubs.sh

source ./regressionTestVariables.sh

File=$1
q="queue"
let arraySize=`cat $File | jq '.subscriptions | length'`
echo $arraySize
count=0
limit=$arraySize
v="/"
while [ $count -lt $limit ]
do
    element=`cat $File | jq '.subscriptions | .['"$count"']'`   
    callback=`cat $File | jq '.subscriptions | .['"$count"'] | .callback' | sed -e 's/"//g'`
    topic=`cat $File | jq '.subscriptions | .['"$count"'] | .topic' | sed -e 's/"//g'`
    vhost=`cat $File | jq '.subscriptions | .['"$count"'] | .vhost' | sed -e 's/"//g'`
    rn=`cat $File | jq '.subscriptions | .['"$count"'] | .resource_name' | sed -e 's/"//g'`
    rt=`cat $File | jq '.subscriptions | .['"$count"'] | .resource_type' | sed -e 's/"//g'`  
    echo "rt: " $rt $q  
    echo "delete:  " $callback $topic $rn
    if [ "$vhost" == "/" ]
        then
            v="%2F"
        else
            v=$vhost
    fi
    if [ "$rt" == "$q" ]
        then
            echo "true"
            ./delSubr.sh $v $rn $topic $callback $User $Pass "q"        
        else
            echo "false"
            ./delSubr.sh $v $rn $topic $callback $User $Pass "x"
    fi
    let count=count+1
done    
