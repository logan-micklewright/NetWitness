function Get-BIOSVersion{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1/Bios"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result.attributes.SystemBiosVersion
}

function Get-StorageControllerVersion{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1/Storage/Oem/Dell/DellControllers/RAID.Slot.1-1"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result.ControllerFirmwareVersion
}

function Get-iDRACVersion{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

   return $result.FirmwareVersion
}

function Get-SystemInfo{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result
}

function Get-VirtualMediaStatus{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result
}

function Remove-VirtualMedia{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.EjectMedia"

    $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result
}

function Get-iDracName{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/EthernetInterfaces/NIC.1"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result.HostName
}


function Set-iDracPassword{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to set the new password")]
        [pscredential] $newCreds
    )
    $NewPassword = $newCreds.GetNetworkCredential().Password
    $body = '{{"Password" : "{0}"}}' -f $NewPassword

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIPredfish/v1/Managers/iDRAC.Embedded.1/Accounts/2"

    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $body

    return $result
}
