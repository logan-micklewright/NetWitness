#!/bin/bash

#IMPORTANT: This script should be called with the MongoDB password as a parameter

#Query the user table, get only results that have a login timestamp, query details are in getUsers.js
mongo admin -u deploy_admin -p $1 --quiet getUsers.js | sed -z 's/^.*CUT_TO_HERE\n//' > NetWitnessUsers.json
mongo admin -u deploy_admin -p $1 --quiet getUsersNoLogin.js | sed -z 's/^.*CUT_TO_HERE\n//' > NetWitnessUsersNoLogin.json

#Clean up the output file so that it can be parsed

#Format the first timestamp getting rid of extra characters
sed -i -r -z 's/\),\n\t\t\tNumberLong\("[0-9]+"\)\n\t\t\]//g' NetWitnessUsers.json

#Get rid of additional timestamps, we only care about the latest one
sed -i -r -z 's/\[\n\t\t\tNumberLong\(//g' NetWitnessUsers.json

#Get rid of extra ] or ) characters that will break parsing, why is Mongo such a mess
sed -i '/^\t\t]/d' NetWitnessUsers.json
sed -i 's/)//g' NetWitnessUsers.json