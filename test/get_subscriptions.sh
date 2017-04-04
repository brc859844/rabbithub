#!/bin/bash

# This script gets a list of all rabbithub subscribers 

curl --request GET http://guest:guest@localhost:15670/subscriptions
