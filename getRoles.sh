#!/bin/bash

#Get the password to connect to mongo
echo "Enter the password to connect to Mongo (deploy_admin)"


#Query the user table, get only results that have a login timestamp, query details are in getUsers.js
mongo admin -u deploy_admin -p $1 --quiet getRoles.js | sed -z 's/^.*CUT_TO_HERE\n//' > NetWitnessRoles.json


