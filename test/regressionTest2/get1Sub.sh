#!/bin/bash
## get the subscription defintion for 1 particular subscriber
## $1 - vhost
## $2 - Resource Type (q or x)
## $3 - queue name
## $4 - topic
## $5 - callback url
## $6 - rabbitmq user
## $7 - rabbitmq password


rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

CBEncoded=$(rawurlencode $5)
echo $CBEncoded
                  
curl -v --request GET "http://$6:$7@localhost:15670/$1/subscriptions/$2/$3?hub.callback=${CBEncoded}&hub.topic=$4"




