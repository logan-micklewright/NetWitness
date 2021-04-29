import requests, json, sys, argparse, warnings

#Define some constants
splunk_server = "192.168.2.102"
splunk_hec_id = "e5bb4c88-7531-441e-9ae1-cea75a7016a0"


#Define the parameters supplied to the script
parser = argparse.ArgumentParser(description="Python script using REST API to get stats")
parser.add_argument('-u', help='API Username', required=True)
parser.add_argument('-p', help='API Password', required=True)
parser.add_argument('-t', help='Service Type', required=True)
parser.add_argument('-i', help='Service IP', required=True)

#Parse the username and password from the supplied values
args=vars(parser.parse_args())
api_user = args["u"]
api_pass = args["p"]
service_type = args["t"]
service_ip = args["i"]


#Set the api urls based on the service type
if service_type == "decoder" :
    #Query decoder service and system
    service_url = 'https://' + service_ip + ':50104/decoder/stats?msg=ls&force-content-type=application/json'
    system_url = 'https://' + service_ip + ':50104/sys/stats?msg=ls&force-content-type=application/json'
elif service_type == "concentrator" :
    #Query concentrator service and system
    service_url = 'https://' + service_ip + ':50105/concentrator/stats?msg=ls&force-content-type=application/json'
    system_url = 'https://' + service_ip + ':50105/sys/stats?msg=ls&force-content-type=application/json'
elif service_type == "broker" :
    #Query broker service and system
    service_url = 'https://' + service_ip + ':50103/broker/stats?msg=ls&force-content-type=application/json'
    system_url = 'https://' + service_ip + ':50103/sys/stats?msg=ls&force-content-type=application/json'
elif service_type == "logdecoder" :
    #Query log decoder service and system
    service_url = 'https://' + service_ip + ':50102/decoder/stats?msg=ls&force-content-type=application/json'
    system_url = 'https://' + service_ip + ':50102/sys/stats?msg=ls&force-content-type=application/json'
elif service_type == "logcollector" :
    #Query log collector service and system
    service_url = 'https://' + service_ip + ':50101/event-processors/logdecoder/stats/destinations/logdecoder?msg=ls&force-content-type=application/json'
    system_url = 'https://' + service_ip + ':50101/sys/stats?msg=ls&force-content-type=application/json'
else : 
    #If the service isn't one of the defined values then we don't know what to query so just end here
    sys.exit("Invalid service type")

#Get the stats output from the api
raw_service_stats = requests.get(service_url,verify=False,auth=(api_user,api_pass))
raw_system_stats = requests.get(system_url,verify=False,auth=(api_user,api_pass))

#Clean up stats from the service and the system into a readable format
stats = {}
for stat in raw_service_stats.json()['nodes']:
    stats[stat['display']] = stat['value']
for stat in raw_system_stats.json()['nodes']:
    stats[stat['display']] = stat['value']   

#Send it to splunk
auth_header = {'Authorization': 'Splunk ' + splunk_hec_id}
event_payload = {"index":"main", "event": stats }
splunk_url = 'https://' + splunk_server + ':8088/services/collector/event'

r = requests.post(splunk_url, headers=auth_header, json=event_payload, verify=False)
