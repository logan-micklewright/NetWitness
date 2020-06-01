$today = (Get-Date).ToString('M-d-yyyy')
$yesterday = (Get-Date).AddDays(-1).ToString('M-d-yyyy')

$user = "admin"
$encryptedPass = Get-Content .\scriptCreds.txt | ConvertTo-SecureString
$credential = New-Object System.Management.Automation.PsCredential($user, $encryptedPass)

# Build auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $credential.GetNetworkCredential().Password)))

# Set proper headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
$headers.Add('Accept','application/json')

# Specify endpoint uri
$uri = "https://nw11testpdec01.isus.emc.com:50104/index/stats"

# Specify HTTP method
$method = "get"

# Send HTTP request
$stats = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -SkipCertificateCheck

# Print response
$stats.nodes
$stats.nodes | Export-Csv -Path DecoderServiceStats.csv

# Query additional services and api nodes
$uri = "https://nw11testpdec01.isus.emc.com:50104/users/groups"
$groups = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -SkipCertificateCheck

#Collect groups present on the decoder, in the larger prod environment this could be used to easily spot check and make sure permissions are matched up across all decoder/broker/concentrator nodes since each must be configured individually
$groups.nodes
$groups.nodes | Export-Csv -Path DecoderGroups-$today.csv

#Collect system statistics from the decoder, this is good for health monitoring
$uri = "https://nw11testpdec01.isus.emc.com:50106/sys/stats"
$decoderSysStats = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -SkipCertificateCheck
$decoderSysStats.nodes
$decoderSysStats.nodes | Export-Csv -Path DecoderSysStats-$today.csv

#Collect system statistics from the broker service, in test this happens to also be the primary server host, in general we'd want to collect system stats from each host for monitoring purposes
$uri = "https://nw11test.isus.emc.com:50103/sys/stats"
$brokerSysStats = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -SkipCertificateCheck
$brokerSysStats.nodes
$brokerSysStats.nodes | Export-Csv -Path BrokerSysStats-$today.csv

#Collect service statistics from the Broker service
$uri = "https://nw11test.isus.emc.com:50103/index/stats"
$brokerServiceStats = Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -SkipCertificateCheck
$brokerServiceStats.nodes | Export-Csv -Path BrokerServiceStats-$today.csv

#Some ideas for what we can do with the info
$serviceStatus = $brokerSysStats.nodes[14].value
if ($serviceStatus -ne 'Ready'){
    #service is DOWN throw an alert, we could generate a SNOW ticket or send an email, but since this is just a proof of concept we'll print to the screen for now
    Write-Host "Broker Service Down"
}

#compare memory used today vs memory used yesterday and look for large spikes
$currentMemUsage = $brokerServiceStats.nodes[0].value
$previousServiceStats = Import-Csv BrokerServiceStats-$yesterday.csv
$difference = $currentMemUsage - $previousServiceStats[0].value
if ($difference -gt ($currentMemUsage * .25)){
    #memory usage spiked more than 25% since yesterday
    Write-Host "Possible memory issue on Broker"
}