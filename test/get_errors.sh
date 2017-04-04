#!/bin/bash

# This script gets all current rabbithub http post errors 

curl --request GET http://guest:guest@localhost:15670/subscriptions/errors
