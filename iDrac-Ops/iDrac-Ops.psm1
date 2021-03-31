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

    $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -StatusCodeVariable statusCode
    
    if($statusCode -eq 200){
        return "Success"
    }else{
        return $result
    }
}

function Set-RemoteMedia{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="The path to the ISO file")]
        [String] $isoPath
    )
    $body = '{{"Image" : "{0}"}}' -f $isoPath

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.InsertMedia"

    $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $body -ContentType 'application/json' -StatusCodeVariable statusCode
    
    if($statusCode -eq 200){
        return "Success"
    }else{
        return $result
    }
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

function Get-iDracAttributes{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/Attributes"

    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers

    return $result.Attributes
}

function Set-iDracSyslog{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide the hostname or IP address to send Syslog alerts to")]
        [String] $syslogAddress
    )
    $body = '{{"SysLog.1.Server1" : "{0}"}}' -f $syslogAddress
    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/Attributes"

    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $body -StatusCodeVariable statusCode -ContentType 'application/json'

    if($statusCode -eq 200){
        return "Success"
    }else{
        return "Possible failure. Return code: $statusCode. Full output: $result"
    }
    
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
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/2"

    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $body -ContentType 'application/json' -StatusCodeVariable statusCode
    
    if($statusCode -eq 200){
        return "Success"
    }else{
        return $result
    }
}
function Set-iDracName{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="The new name for the idrac")]
        [String] $newName
    )
    $JsonBody = @{'HostName'= $newName} | ConvertTo-Json -Compress

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/EthernetInterfaces/NIC.1"

    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $JsonBody -ContentType 'application/json' -StatusCodeVariable statusCode
    
    if($statusCode -eq 200){
        return "Success"
    }else{
        return $result
    }
}

function Invoke-PowerCycle{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="The type of powercycle action to take (PowerCycle, GracefulRestart, ForceOff, ForceOn, ForceRestart")]
        [String] $powerCycleType
    )
    $body = '{{"ResetType" : "{0}"}}' -f $powerCycleType

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"

    $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $body -ContentType 'application/json'

    return $result
}

function Invoke-FirmwareUpdate{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="The local path to the update file to apply")]
        [String] $updateFilePath,

        [Parameter(Mandatory=$true, HelpMessage="The name of the update file to apply")]
        [String] $updateFileName
    )
    #Step 1 in updating firmware is to get the 'ETag' value

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/UpdateService/FirmwareInventory"
    $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -Headers $headers -ResponseHeadersVariable responseHeaders -SkipCertificateCheck
    $ETag=$responseHeaders.ETag

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add('If-Match',$ETag)
    $headers.Add('Accept','application/json')

    # Code to read the image file for download to the iDRAC
    $complete_path="$updateFilePath\$updateFileName"

    $CODEPAGE = "iso-8859-1"
    $fileBin = [System.IO.File]::ReadAllBytes($complete_path)
    $enc = [System.Text.Encoding]::GetEncoding($CODEPAGE)
    $fileEnc = $enc.GetString($fileBin)
    $boundary = [System.Guid]::NewGuid().ToString()

    $LF = "`r`n"
    $body = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$updateFileName`"",
            "Content-Type: application/octet-stream$LF",
            $fileEnc,
            "--$boundary",
            "Content-Disposition: form-data; name=`"importConfig`"; filename=`"$updateFileName`"",
            "Content-Type: application/octet-stream$LF",
            "--$boundary--$LF"
    ) -join $LF

    $result = Invoke-WebRequest -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -SkipHeaderValidation -Headers $headers -Body $body -ContentType "multipart/form-data; boundary=`"$boundary`""
    
    #Check whether the file was uploaded successfully
    if ($result.StatusCode -ne 201){
        Write-Host "The firmware file failed to upload to the idrac. Status code: $statusCode"
        return $result
    }else{
        #Now that the image file is uploaded time to install it
        $headers = @{"Accept"="application/json"}
        $JsonBody = '{"ImageURI":"'+$result.headers.location+'"}'
        $uri = "https://$idracIP/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate"
        $result = Invoke-RestMethod -SkipCertificateCheck -Uri $uri -Credential $apiCreds -Body $JsonBody -Method POST -Headers $headers -ContentType 'application/json'
        return $result
    }
    
}