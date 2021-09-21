$apiCreds = Get-Credential

$idrac = Read-Host -Prompt "What idrac would you like to query?"

$headers = @{"Accept"="application/json"}

$i=1
$accounts = @()
while($i -lt 5){
    $url = "https://$idrac/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$i"
    $response = Invoke-RestMethod -Method Get -Uri $url -Credential $apiCreds -Headers $headers -ResponseHeadersVariable responseHeaders -SkipCertificateCheck
    $accounts = $accounts + $response
    $i++
}
$accounts