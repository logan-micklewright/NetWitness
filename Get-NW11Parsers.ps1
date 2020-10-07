Import-Module .\NetWitness-Ops

$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

$decoders = Get-NWDecoders -NWHost "10.178.203.182"

$parsers = Get-Parsers -apiCreds $apiCreds -NWServices $decoders

$parsers | $par-Csv -Path ./parsers.csv

$parsers | Out-file -Path ./parsers.txt