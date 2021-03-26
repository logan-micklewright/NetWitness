Import-Module .\NetWitness-Ops

$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

$nwServer = Read-Host -Prompt "Enter hostname or IP of NW server to query"
$decoders = Get-NWDecoders -NWHost $nwServer

$feedname = Read-Host -Prompt "Enter the name of the feed to delete"

Remove-Feed -apiCreds $apiCreds -NWServices $decoders -feed $feedname