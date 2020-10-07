[CmdletBinding()]
param (    
    [Parameter(Mandatory)]
    [string]$destinationHost,

    [Parameter(Mandatory)]
    [string]$serviceType
)

$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"
$updateURI = "/rest/config/ssl?msg=set&force-content-type=text/plain&value=on"

$appliancePort="50106"

$port = ""
$service = $serviceType


if($service -eq "concentrator"){
    $port = "50105"
}elseif($service -eq "decoder"){
    $port = "50104"
}elseif($service -eq "broker"){
    $port = "50103"
}elseif($service -eq "logdecoder"){
    $port = "50102"
}elseif($service -eq "logcollector"){
    $port = "50101"
}else{
    Write-Host "Service Type must be either broker, concentrator, decoder, logdecoder, or logcollector"
    return
}
Write-Host "Updating $service on $destinationHost"
$serviceURI = "http://$destinationHost"+":"+$port+$updateURI
Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication

$serviceStopURI="http://$destinationHost"+":"+$appliancePort+"/appliance?msg=stop&force-content-type=text/plain&service=$service"
$serviceStartURI="http://$destinationHost"+":"+$appliancePort+"/appliance?msg=start&force-content-type=text/plain&service=$service"
        
Invoke-RestMethod -Uri "$serviceStopURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
Start-Sleep -s 10
Invoke-RestMethod -Uri "$serviceStartURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication

$applianceURI = "http://$destinationHost"+":"+$appliancePort+$updateURI
$serviceRestartURI = "http://$destinationHost"+":"+$appliancePort+"/sys?msg=shutdown&force-content-type=text/plain&reason=Enable%20SSL"
Write-Host "Updating Appliance Service on $destinationHost"
Invoke-RestMethod -Uri "$applianceURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
Invoke-RestMethod -Uri "$serviceRestartURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
