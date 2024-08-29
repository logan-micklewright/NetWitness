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
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$false, HelpMessage="Is the iDRAC on a legacy firmware version (Older than 4.x)")]
        [Switch] $legacy
    )
    $headers = @{"Accept"="application/json"}
    if($legacy){
        $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1/Storage/RAID.Slot.1-1"
        $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers
        return $result.StorageControllers.FirmwareVersion
    }else{
        $uri = "https://$idracIP/redfish/v1/Systems/System.Embedded.1/Storage/Oem/Dell/DellControllers"
        $result = Invoke-RestMethod -Method GET -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers
        $controller = $result.Members | Where-Object {$_.Id -match "RAID.Slot"} 
        return $controller.ControllerFirmwareVersion
    }

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
    $sharetype="NFS"
    #Split the IP address and the share into separate variables
    $ipaddress=$isoPath.Split(":")[0]
    $sharename=($isoPath.Split(":")[1])
    #Split the share path and the actual filename into separate variables
    $imagename=$sharename.Substring($sharename.LastIndexOf("\")+1)
    $sharename=$sharename.Substring(0,$sharename.LastIndexOf("\"))

    $JsonBody = @{'ImageName'=$imagename;'IPAddress'=$ipaddress;'ShareType'=$sharetype;'ShareName'=$sharename} | ConvertTo-Json -Compress

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.ConnectNetworkISOImage"

    $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $JsonBody -ContentType 'application/json' -StatusCodeVariable statusCode
    
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
    $idrac_username = $apiCreds.UserName
    $idrac_password = $apiCreds.GetNetworkCredential().Password
    $CurlExecutable = "curl.exe"
    $idrac_username_password = $idrac_username+":"+$idrac_password 

    $result = & $CurlExecutable --request POST https://$idracIP/redfish/v1/UpdateService/FirmwareInventory --header "If-Match: $ETag" --header "content-type: multipart/form-data" --form file=@$complete_path --insecure -u $idrac_username_password
    $result = [string]$result
    $get_version = [regex]::Match($result, 'Available.+?,').captures.groups[0].value
    $get_version = $get_version.Replace(",","")
    $get_version = $get_version.Replace('"',"")
    $global:available_entry = "/redfish/v1/UpdateService/FirmwareInventory/"+$get_version

    #Check whether the file was uploaded successfully
    if ($result.Contains("Package successfully downloaded")){
        #Now that the image file is uploaded time to install it
        Write-Host "Firmware file uploaded successfully. Scheduling the install."
        $headers = @{"Accept"="application/json"}
        $image_uri = [string]$global:available_entry
        $JsonBody = @{'ImageURI'= $image_uri} | ConvertTo-Json -Compress
        $uri = "https://$idracIP/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate"
        $result = Invoke-RestMethod -SkipCertificateCheck -Uri $uri -Credential $apiCreds -Body $JsonBody -Method POST -Headers $headers -ContentType 'application/json'
        return $result
    }else{
        Write-Host "The firmware file failed to upload to the idrac. $result"
        return $result        
    }
    
}

function Add-iDracUser{
    param(
        [Parameter(Mandatory=$true, HelpMessage="The IP address of the iDRAC to query")]
        [System.Object] $idracIP,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to set the password for the new user")]
        [pscredential] $newCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide a name for the new user")]
        [string] $userName,

        [Parameter(Mandatory=$true, HelpMessage="The role to add the new user to")]
        [string] $role,

        [Parameter(Mandatory=$true, HelpMessage="Provide a numberical user id between 3-20")]
        [string] $userId
    )
    $NewPassword = $newCreds.GetNetworkCredential().Password
    
    $JsonBody = @{UserName = $userName; Password= $NewPassword; RoleId = $role; Enabled = $true} | ConvertTo-Json -Compress

    $headers = @{"Accept"="application/json"}
    $uri = "https://$idracIP/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$userId"

    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Credential $apiCreds -SkipCertificateCheck -Headers $headers -Body $JsonBody -ContentType 'application/json' -StatusCodeVariable statusCode
    
    if($statusCode -eq 200){
        return "Success"
    }else{
        return $result
    }
}
