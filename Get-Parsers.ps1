Import-Module .\NetWitness-Ops

$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

$nwServer = Read-Host -Prompt "Enter hostname or IP of NW server to query"
$decoders = Get-NWDecoders -NWHost $nwServer

$parsers = Get-Parsers -apiCreds $apiCreds -NWServices $decoders

$parsers | Out-Csv -Path ./parsers.csv

$parsers | Out-file -Path ./parsers.txt