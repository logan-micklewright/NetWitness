function Get-NWServices{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the hostname or IP of the NW head unit to query for available services")]
        [String] $NWHost
    )

    #Create an object to hold our services once we've collected and parsed the data
    $NWServices = @()

    #Get a list of all known services using the orchestration client on the head unit
    $rawServices = ssh root@$NWHost 'orchestration-cli-client -s'


    #The last two lines returned are always messages about the status rather than actual hosts or services, strip them or it breaks proper parsing of the rest
    $rawServices = $rawServices[0..($rawServices.Length-3)]

    #Output from the orchestration client unfortunately has a lot of extra junk in front of it, need to strip that to get the actual data, so chop the beginning of each line up to the part we care about
    $i=0
    while($i -lt $rawServices.Length){
        $rawServices[$i] = $rawServices[$i].Substring(111)
        $i++
    }

    #When the services are being parsed from the raw input there's actually a column for TLS but I don't care about that so I'm naming the column port and using it to hold the port number value once I split it from the IP string below
    #It's not necessary, just a little faster than removing the unneeded object property and then adding a new one
    $services = $rawServices | ConvertFrom-Csv -Header ID, Service, IP, Port
    foreach($service in $services){
        $service.IP = $service.IP.Substring(5)
        $IPandPort = $service.IP.split(":")

        #What we really want for port is the API ports, so a little conversion before we return the values
        $Port = ""
        switch($IPandPort[1]){
            "56002" {$Port = "50102"}
            "56003" {$Port = "50103"}
            "56004" {$Port = "50104"}
            "56005" {$Port = "50105"}
            Default {$Port = "Unknown"}
        }

        $s = New-Object -TypeName psobject
        $s | Add-Member -MemberType Noteproperty -Name ID -Value $service.ID.Substring(3)
        $s | Add-Member -MemberType Noteproperty -Name Name -Value $service.Service.Substring(5)
        $s | Add-Member -MemberType Noteproperty -Name IP -Value $IPandPort[0]
        $s | Add-Member -MemberType Noteproperty -Name Port -Value $Port
        $NWServices+= $s
    }
    Return $NWServices
}

function Get-NWHosts{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the hostname or IP of the NW head unit to query for available hosts")]
        [String] $NWHost
    )

    #Create an object to hold our services once we've collected and parsed the data
    $NWHosts = @()

    #Get a list of all known services using the orchestration client on the head unit
    $rawHosts = ssh root@$NWHost 'orchestration-cli-client -l'


    #The last two lines returned are always messages about the status rather than actual hosts or services, strip them or it breaks proper parsing of the rest
    $rawHosts = $rawHosts[0..($rawHosts.Length-3)]

    #Output from the orchestration client unfortunately has a lot of extra junk in front of it, need to strip that to get the actual data, so chop the beginning of each line up to the part we care about
    $i=0
    while($i -lt $rawHosts.Length){
        $rawHosts[$i] = $rawHosts[$i].Substring(108)
        $i++
    }


    #Now that the output is cleaned a little it can be parsed into a usable format, it's obviously not a csv file but format is close enough the csv import commandlet parses it nicely
    $hosts = $rawHosts | ConvertFrom-Csv -Header ID, IP, Name, Version
    foreach($server in $hosts){
        $h = New-Object -TypeName psobject
        $h | Add-Member -MemberType Noteproperty -Name ID -Value $server.ID.Substring(3)
        $h | Add-Member -MemberType Noteproperty -Name Name -Value $server.Name.Substring(5)
        $h | Add-Member -MemberType Noteproperty -Name IP -Value $server.IP.Substring(5)
        $h | Add-Member -MemberType Noteproperty -Name Version -Value $server.Version.Substring(8)
        $h | Add-Member -MemberType Noteproperty -Name ApplianceUpdated -Value $false
        $NWHosts+= $h
    }
    Return $NWHosts
}

function Set-NWSSL{
    param(
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least a IP, Port, and Name")]
        [System.Object] $NWService,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $NWHost = $NWService.IP
    $Port = $NWService.Port
    $ServiceType = $NWService.Name
    
    #If the port is 50106 we're updating the appliance service which is a little different from the other service types
    if($Port -eq "50106"){
        $applianceURI = "https://$NWHost"+":50106"+$updateURI
        $serviceRestartURI = "https://$NWHost"+":50106/sys?msg=shutdown&force-content-type=text/plain&reason=Enable%20SSL"
        Invoke-RestMethod -Uri "$applianceURI" -Credential $apiCreds -SkipCertificateCheck
        Invoke-RestMethod -Uri "$serviceRestartURI" -Credential $apiCreds -SkipCertificateCheck
    }else{
        $updateURI = "/rest/config/ssl?msg=set&force-content-type=text/plain&value=on"
        $serviceURI = "https://$NWHost"+":"+$Port+$updateURI        
        Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck

        $serviceStopURI="https://$NWHost"+":50106/appliance?msg=stop&force-content-type=text/plain&service=$ServiceType"
        $serviceStartURI="https://$NWHost"+":50106/appliance?msg=start&force-content-type=text/plain&service=$ServiceType"
        
        Invoke-RestMethod -Uri "$serviceStopURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 10
        Invoke-RestMethod -Uri "$serviceStartURI" -Credential $apiCreds -SkipCertificateCheck
    }   
}

function Set-NWPassword{
    param(
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Port")]
        [System.Object] $NWService,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object with the desired new password")]
        [pscredential] $newCreds
    )
    $newPass = $newCreds.GetNetworkCredential().Password
    $passwordUpdateURI = "/users/accounts/admin/config/password?msg=set&force-content-type=text/plain&value=$newPass"
    $thisIP = $NWService.IP
    $thisPort = $NWService.Port

    $serviceURI = "https://$thisIP"+":"+$thisPort+$passwordUpdateURI
    Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck
}

function Get-NWRoles{
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Port")]
        [System.Object] $NWService,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $getRoles = "/users/groups?msg=ls&force-content-type=application/json"
    $IP = $NWService.IP
    $Port = $NWService.Port
    $uri = "https://$IP"+":"+$Port+$getRoles
    $groups = Invoke-RestMethod -Uri $uri -Credential $apiCreds -SkipCertificateCheck
    return $groups.nodes
}

function Set-NWRoles{
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Port")]
        [System.Object] $NWService,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Roles to apply, this should be from the output of Get-NWRoles")]
        [System.Object] $roles
    )
    $builtInRoles = "Administrators", "Aggregation", "Analysts", "Data_Privacy_Officers", "Malware_Analysts", "Operators", "SOC_Managers"
    $destinationHost = $NWService.IP
    $port = $NWService.Port
    $baseURI = "https://$destinationHost"+":"+$port
    foreach($role in $roles){
        if($builtInRoles -notcontains $role.name){
            $name = $role.name
            $rolesToAdd = $role.value -replace ",","%2C"
            $addRoles = "/users/groups?msg=add&force-content-type=text/plain&name=$name&roles=$rolesToAdd"
            Invoke-RestMethod -Uri $baseURI$addRoles -Credential $apiCreds -SkipCertificateCheck
        }
    }

}

function Copy-NWRoles{
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,

        [Parameter(Mandatory=$true, HelpMessage="Provide host name or IP to copy roles from")]
        [string]$referenceHost,
        
        [Parameter(Mandatory=$true, HelpMessage="Provide host name or IP to copy roles to")]
        [string]$destinationHost,

        [Parameter(Mandatory=$true, HelpMessage="Provide the port used to connect to the API")]
        [string]$port
    )
    
    $builtInRoles = "Administrators", "Aggregation", "Analysts", "Data_Privacy_Officers", "Malware_Analysts", "Operators", "SOC_Managers"
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
}