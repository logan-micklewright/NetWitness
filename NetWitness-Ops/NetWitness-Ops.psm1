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

function Get-NWDecoders{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Enter the hostname or IP of the NW head unit to query for available hosts")]
        [String] $NWHost
    )
    $decoders = Get-NWServices -NWHost $NWHost | Where-Object -Property name -eq "Decoder"
    $NWHosts = Get-NWHosts -NWHost $NWHost
    foreach ($dec in $decoders) { 
        $dec.name = $NWHosts | Where-Object -FilterScript {$_.IP -eq $dec.IP} | Select-Object -ExpandProperty Name 
    }
    return $decoders
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
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="A NW service object which should contain at least an IP and Port")]
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
    $builtInRoles = "Administrators", "Aggregation", "Analysts", "Data_Privacy_Officers", "Malware_Analysts", "Operators", "SOC_Managers", "Reporting_Engine_Content_Administrators"
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
    
    $builtInRoles = "Administrators", "Aggregation", "Analysts", "Data_Privacy_Officers", "Malware_Analysts", "Operators", "SOC_Managers", "Reporting_Engine_Content_Administrators"
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

function Get-Parsers {
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Name")]
        [System.Object] $NWServices,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $queryURI = ":50104/decoder/parsers?msg=content&force-content-type=application/json&type=parsers"
    $output = @{}
    foreach($service in $NWServices){
        $ip = $service.IP
        $name = $service.Name
        $serviceURI = "https://$ip"+$queryURI
        Write-Host "Querying Parsers on $name"
        $result = Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck
        foreach ($node in $result.nodes){
            if (($node.name -ne "uuid") -and ($node.name -ne "dateInstalled")){
                $parsers = $result.nodes | Where-Object -FilterScript {($_.name -ne "uuid") -and ($_.name -ne "dateInstalled")} | Select-Object -Property name
                $output[$name] = $parsers.name
            }
        }
    }

return $output
}

function Set-NWStorage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the host to configure")]
        [string]$nodeIP,
        [Parameter(Mandatory=$true, HelpMessage="Provide the type of service on the host")]
        [string]$serviceType
    )

    $appliancePort="50106"
    $concentratorPort="50105"
    $decoderPort="50104"
    $logdecoderPort="50102"

    #$endpointToConfig = Read-Host -Prompt "Enter the IP of the host you want to configure"
    #$service = Read-Host -Prompt "Enter the type of host this is"
    $endpointToConfig = $nodeIP
    $service = $serviceType
    if($service -ne "concentrator" -And $service -ne "decoder" -And $service -ne "logdecoder"){
        Write-Host "Service Type must be either concentrator, decoder or logdecoder"
        return
    }

    $apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

    #List storage controllers/enclosures
    $raidList = "/appliance?msg=raidList&force-content-type=application/json"
    $apiURI = "https://$endpointToConfig"+":"+$appliancePort+$raidList
    $controllers = Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck

    <#NW api returns data as a bunch of raw text, even when selecting json as the return type it's just a big string, example:
    Controller 0 at PCI Address 18:00.0, Enclosure 64
        Vendor:  DP
        Model:   BP14G+EXP
        In Use:  true
        Drives:  931.512 GB HDD x 2
                1.819 TB HDD x 2
        Devices: sda /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0
                sdb /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:1:0

    Controller 1 at PCI Address 3b:00.0, Enclosure 250
        Vendor:  DELL
        Model:   MD1400
        In Use:  true
        Drives:  10.692 TB HDD x 12
        Devices: sdc /dev/disk/by-path/pci-0000:3b:00.0-scsi-0:2:0:0
                sdd /dev/disk/by-path/pci-0000:3b:00.0-scsi-0:2:1:0

    So we do a couple things here, first trim the whitespace at the beginning and end
    Then split on blank lines since there's a blank line between each enclosure, so now we have chunks of properties we can work with
    Loop through those chunks and take the first line which contains controller and enclosure number, ex: Controller 1 at PCI Address 3b:00.0, Enclosure 250 use a regex to replace the junk in the middle we don't care about so we get Controller 1, Enclosure 250 
    Split that at the comma to get Controller 1 and Enclosure 250 onto separate lines and now it matches the format of the other properties
    Finally replace the : with = in each line so that we can pass the whole thing to ConvertFrom-StringData and get something pretty and usable
    #>
    $controllers = $controllers.string.trim()
    $controllers = $controllers.Split("`n`n")
    foreach ($controller in $controllers){
        $controllerInfo = (($controller -split '\n')[0] -replace "\sat.*,",",").Split(", ")
        $controller = $controller.Substring($controller.IndexOf('Vendor'))
        $controller = $controller -replace "             .*"
        $controller = ($controllerInfo -replace " ","=") + ($controller -replace "Devices:","Devices: ")
        $controller =  $controller -replace ': ','=' | ConvertFrom-StringData
        #If the enclosure is already in use don't touch it, only configure unused enclosures, the api will fail the request anyway if it's in use but I don't trust that
        if ($controller.'In Use' -eq "false"){
            $enclosure = $controller.Enclosure
            $number = $controller.Controller
            $raidNew = "/appliance?msg=raidNew&force-content-type=text/plain&controller=$number&enclosure=$enclosure&scheme=$service&commit=1"
            $apiURI = "https://$endpointToConfig"+":"+$appliancePort+$raidNew
            Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        }
    }

    #Now that we have created raids on each enclosure, get a list of the storage devices available so we can partition them
    $devList = "/appliance?msg=devlist&force-content-type=text/plain"
    $apiURI = "https://$endpointToConfig"+":"+$appliancePort+$devList
    $devices = Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck

    $devices = $devices.trim()
    $devices = $devices.Split("`n")

    $storageDevices = @()
    foreach($device in $devices){
        $deviceName = "name="+$device.Substring(0,3)
        $deviceSize = $device.Substring($device.IndexOf("size"))
        $deviceSize = $deviceSize -replace '="','='
        $deviceSize = ($deviceSize -split '"')[0]
        $deviceUsed = $device.Substring($device.IndexOf("used"))

        $deviceProps = $deviceName + "`n" + $deviceSize + "`n" + $deviceUsed
        $deviceProps = $deviceProps | ConvertFrom-StringData

        if($deviceProps.used -eq "0"){
            $sd = New-Object -TypeName psobject
            $sd | Add-Member -MemberType Noteproperty -Name DeviceName -Value $deviceProps.name
            $sd | Add-Member -MemberType Noteproperty -Name Size -Value $deviceProps.size
            $sd | Add-Member -MemberType Noteproperty -Name Used -Value $deviceProps.used
            $storageDevices+= $sd
        }
    }

    $storageDevices

    #Decoders and log decoders both have a simliar layout, decodersmall volume and then decoder volume, where decodersmall must be partitioned and allocated first
    #Concentrators follow a different pattern with index and concentrator volumes where index is the smaller volume and must be partitioned second but allocated first
    if($service -eq "decoder" -Or $service -eq "logdecoder"){
        #First thing to check is how many storage devices we have, which should always be an even number otherwise we have mismatched drives
        if($storageDevices.Length%2 -eq 0){
            #If we sort by size of the storage device the first half of the devices will be the decodersmall volumes, second half (or first half if sorted descending) will be decoder volumes
            $decoderSmall = $storageDevices | Sort-Object -Property Size | Select-Object DeviceName -First $storageDevices.Length/2
            $decoder = $storageDevices | Sort-Object -Property Size | Select-Object DeviceName -Last $storageDevices.Length/2

            foreach($sd in $decoderSmall){
                $name=$sd.DeviceName
                $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=$service"+"small&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            }
            foreach($sd in $decoder){
                $name=$sd.DeviceName
                $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=$service&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            }
            Start-Sleep -s 5

            #Once storage devices are partitioned they can then be allocated to the services
            $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+"small&commit=1"
            Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            Start-Sleep -s 2
            $i=0
            #Storage volumes start with just the volume name eg decodersmall, then subsequent devices with the same volume get a number starting with 0
            #So if you have for example 4 decodersmall volumes they would be decodersmall, decodersmall0, decodersmall1, and decodersmall2
            #This means if there are 8 total storage devices then length/2 is 4 but we need just 0, 1, and 2
            while($i -lt (($storageDevices.Length/2)-1)){
                $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+"small"+$i+"&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
                Start-Sleep -s 5
                $i++
            }        
            $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service&commit=1"
            Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            Start-Sleep -s 2
            $i=0
            while($i -lt (($storageDevices.Length/2)-1)){
                $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+$i+"&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
                Start-Sleep -s 10
                $i++
            }
        }else{
            Write-Host "Invalid drive configuration, manual configuration required"
            return
        }
    }

    if($service -eq "concentrator"){
        if($storageDevices.Length%2 -eq 0){
            $index = $storageDevices | Sort-Object -Property Size | Select-Object DeviceName -First $storageDevices.Length/2
            $concentrator = $storageDevices | Sort-Object -Property Size | Select-Object DeviceName -Last $storageDevices.Length/2
            foreach($sd in $concentrator){
                $name=$sd.DeviceName
                $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=concentrator&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            }
            foreach($sd in $index){
                $name=$sd.DeviceName
                $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=index&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            }
            Start-Sleep -s 5
            #Once storage devices are partitioned they can then be allocated to the services
            $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=index&commit=1"
            Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            Start-Sleep -s 2
            $i=0
            while($i -lt (($storageDevices.Length/2)-1)){
                $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=index$i&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
                Start-Sleep -s 5
                $i++
            }
            $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=concentrator&commit=1"
            Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
            Start-Sleep -s 2
            while($i -lt (($storageDevices.Length/2)-1)){
                $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=concentrator$i&commit=1"
                Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
                Start-Sleep -s 10
                $i++
            }
        }else{
            Write-Host "Invalid drive configuration, manual configuration required"
            return
        }
    }

    if($service -eq "decoder"){    
        #Finally once the storage has been allocated we need to update config values for the service
        $apiURI="https://$endpointToConfig"+":"+$decoderPort+"/decoder?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$decoderPort+"/database?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
    }
    if($service -eq "logdecoder"){
        #Finally once the storage has been allocated we need to update config values for the service
        $apiURI="https://$endpointToConfig"+":"+$logdecoderPort+"/decoder?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$logdecoderPort+"/database?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
    }

    if($service -eq "concentrator"){
        #Finally once the storage has been allocated we need to update config values for the service
        $apiURI="https://$endpointToConfig"+":"+$concentratorPort+"/concentrator?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$concentratorPort+"/database?msg=reconfig&force-content-type=text/plain&update=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
    }
}

function New-NWHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide the name of the host to add")]
        [string]$NWHostName,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the host to add")]
        [string]$nodeIP,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the head unit")]
        [string]$NWHeadUnit
    )
    
    $rawSaltInfo = ssh root@$nodeIP cat /etc/salt/minion
    $rawSaltInfo = $rawSaltInfo[4].Split(":")
    $minionID = $rawSaltInfo[1].Trim()

    ssh root@$NWHeadUnit orchestration-cli-client --register-host -d $minionID -n $NWHostName -o $nodeIP --ipv4 $nodeIP
}

function New-NWService {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide the type of service to install")]
        [string]$ServiceType,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the host to add the service to")]
        [string]$nodeIP,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the head unit")]
        [string]$NWHeadUnit
    )
    
    $rawSaltInfo = ssh root@$NWHeadUnit salt -G "ipv4:$nodeIP" grains.get id
    $rawSaltInfo = $rawSaltInfo.Split(":")
    $minionID = $rawSaltInfo[0].Trim()

    ssh root@$NWHeadUnit orchestration-cli-client --install -c $ServiceType -o $minionID
}

function Update-NWHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the host to update")]
        [string]$nodeIP,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the head unit")]
        [string]$NWHeadUnit
    )
    
    $rawSaltInfo = ssh root@$NWHeadUnit salt -G "ipv4:$nodeIP" grains.get id
    $rawSaltInfo = $rawSaltInfo.Split(":")
    $minionID = $rawSaltInfo[0].Trim()

    $currentVersion = ssh root@$NWHeadUnit upgrade-cli-client --list | grep AUSPLNWHU
    $currentVersion = $currentVersion.Substring($currentVersion.length-5)

    ssh root@$NWHeadUnit upgrade-cli-client -u --host-key $minionID --version $currentVersion
}

function New-NWWarehouseConnector {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the host to install warehouse connector on")]
        [string]$nodeIP,
        [Parameter(Mandatory=$true, HelpMessage="Provide the IP of the head unit")]
        [string]$NWHeadUnit
    )
    ssh root@$NWHeadUnit warehouse-installer --host-addr $nodeIP
}

function Remove-Feed {
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Name")]
        [System.Object] $NWServices,

        [Parameter(Mandatory=$true, HelpMessage="The name of the feed to remove")]
        [System.Object] $feed,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $queryURI = ":50104/decoder/parsers?msg=feed&force-content-type=text/plain&op=delete&file=$feed"
    foreach($service in $NWServices){
        $ip = $service.IP
        $name = $service.Name
        $serviceURI = "https://$ip"+$queryURI
        Write-Host "Deleting feed on $name"
        Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck
    }
}

function Get-Feeds {
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Name")]
        [System.Object] $NWServices,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $queryURI = ":50104/decoder/parsers?msg=content&force-content-type=application/json&type=feeds"
    $output = @{}
    foreach($service in $NWServices){
        $ip = $service.IP
        $name = $service.Name
        $serviceURI = "https://$ip"+$queryURI
        Write-Host "Querying Feeds on $name"
        $result = Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck
        foreach ($node in $result.nodes){
            if (($node.name -ne "name") -and ($node.name -ne "dateInstalled")){
                $parsers = $result.nodes | Where-Object -FilterScript {($_.name -ne "name") -and ($_.name -ne "dateInstalled")} | Select-Object -Property name
                $output[$name] = $parsers.name
            }
        }
    }

return $output
}