[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$referenceHost,
    
    [Parameter(Mandatory)]
    [string]$destinationHost,

    [Parameter(Mandatory)]
    [string]$serviceType
)
$port = ""
$service = $serviceType
$builtInRoles = "Administrators", "Aggregation", "Analysts", "Data_Privacy_Officers", "Malware_Analysts", "Operators", "SOC_Managers", "Reporting_Engine_Content_Administrators"


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
    Write-Host "Service Type must be either broker, concentrator, decoder or logdecoder"
    return
}

#Get some credentials to use for our api requests. These will be used for both the reference node as well as the node being configured so hopefully the password has been set on the node being configured before you ran this script
$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"
$baseRefURI = "https://$referenceHost"+":"+$port
$baseURI = "https://$destinationHost"+":"+$port


$getRoles = "/users/groups?msg=ls&force-content-type=application/json"
$groups = Invoke-RestMethod -Uri $baseRefURI$getRoles -Credential $apiCreds -SkipCertificateCheck
$groups = $groups.nodes

foreach($group in $groups){
    if($builtInRoles -notcontains $group.name){
        $name = $group.name
        $roles = $group.value -replace ",","%2C"
        $addRoles = "/users/groups?msg=add&force-content-type=text/plain&name=$name&roles=$roles"
        Invoke-RestMethod -Uri $baseURI$addRoles -Credential $apiCreds -SkipCertificateCheck
    }
}