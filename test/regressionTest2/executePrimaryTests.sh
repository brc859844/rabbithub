#!/bin/bash
# This script will execute all test scripts
# - create rabbitmq vhost and schema generateRabbitmqSchemaDef.sh; importRabbitmqDefinitions.sh
# - create subscribers sub*.sh
# - publish messages
#  Prerequiste:  - the subscriber must be running and available
#                - configure the regressionTestVariables.sh

DATE=`date +"%Y-%m-%d"`
logFile=rabbithubTest.$DATE.log

exec >> $logFile 2>&1
echo `date +"%Y-%m-%d %T"`"|+++++++++++++++START TEST+++++++++++++++"
source regressionTestVariables.sh
echo "Generate Rabbitmq Defintions"
./generateRabbitmqSchemaDef.sh 

echo "Import Rabbitmq Defintions"
./importRabbitmqDefinitions.sh

echo "Create Subscribers"
./subq-q1.sh
./subq-q2.sh
./subq-q3.sh
./subq-q4.sh
./subjsonall.sh
./subjson.sh
./subq-q1allparams.sh
./subq-q1basicauth.sh
./subq-q1contactall.sh
./subq-q1contactapp.sh
./subq-q1hamode-1.sh
./subq-q1hamode-all.sh
./subq-q1lease.sh
./subq-q1maxtps-2.sh
./subx-x1.sh

echo "Publish Messages"
./pubxdirect1.sh
./pubxfanout1.sh
./pubxheader1.sh
./pubxtopic1.sh
# if subscriber is configured to return a 400 when word "bad" is in the message body, this post will return a 400
./pubxdirect1-bad.sh

echo `date +"%Y-%m-%d %T"`"|+++++++++++++++END TEST+++++++++++++++"
