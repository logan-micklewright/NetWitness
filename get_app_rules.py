import requests, json, sys, argparse

#Define the parameters supplied to the script
parser = argparse.ArgumentParser(description="Python script using REST API to get stats")
parser.add_argument('-u', help='API Username', required=True)
parser.add_argument('-p', help='API Password', required=True)
parser.add_argument('-s', help='Server to pull from', required=True)

#Parse the username and password from the supplied values
args=vars(parser.parse_args())
api_user = args["u"]
api_pass = args["p"]
reference_decoder = args["s"]

#Define a function to fetch the info from the API and clean it up
def get_app_rules(api_user, api_pass, server):
    service_url = 'https://' + server + ':50104/decoder/config/rules/application?msg=ls&force-content-type=application/json'
    response = requests.get(service_url,verify=False,auth=(api_user,api_pass))
    #Clean up response into a readable format
    rules = {}
    for rule in response.json()['nodes']:
        rules[rule['name']] = rule.get('value')
    
    return rules

#Main
app_rules = get_app_rules(api_user, api_pass, reference_decoder)
print(app_rules)
