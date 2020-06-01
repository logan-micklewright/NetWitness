[CmdletBinding()]
param (
    [Parameter()]
    [string]$nodeIP,
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

if($service -eq "decoder" -Or $service -eq "logdecoder"){
    #First thing to check is whether we have 2 storage devices or 4 (1 enclosure or 2)
    if($storageDevices.Length -eq 4){
        $decoderSmall = $storageDevices | sort Size | select DeviceName -first 2
        $decoder = $storageDevices | sort Size -descending | select DeviceName -first 2
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
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+"small0&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 5
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+"0&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 10

    }elseif($storageDevices.Length -eq 2){
        $decoderSmall = $storageDevices | sort Size | select DeviceName -first 1
        $decoder = $storageDevices | sort Size -descending | select DeviceName -first 1
        $name=$decoderSmall.DeviceName
        $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=$service"+"small&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $name=$decoder.DeviceName
        $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=$service&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 5

        #Once storage devices are partitioned they can then be allocated to the services
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service"+"small&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=$service&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 10
    }else{
        Write-Host "Invalid drive configuration, manual configuration required"
        return
    }
}

if($service -eq "concentrator"){
    if($storageDevices.Length -eq 4){
        $index = $storageDevices | sort Size | select DeviceName -first 2
        $concentrator = $storageDevices | sort Size -descending | select DeviceName -first 2
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
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=index0&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 5
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=concentrator&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=concentrator0&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 10

    }elseif($storageDevices.Length -eq 2){
        $index = $storageDevices | sort Size | select DeviceName -first 1
        $concentrator = $storageDevices | sort Size -descending | select DeviceName -first 1
        $name=$concentrator.DeviceName
        $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=concentrator&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $name=$index.DeviceName
        $apiURI = "https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=partNew&force-content-type=text/plain&name=$name&service=$service&volume=index&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 5

        #Once storage devices are partitioned they can then be allocated to the services
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=index&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 2
        $apiURI="https://$endpointToConfig"+":"+$appliancePort+"/appliance?msg=srvAlloc&force-content-type=text/plain&service=$service&volume=concentrator&commit=1"
        Invoke-RestMethod -Uri "$apiURI" -Credential $apiCreds -SkipCertificateCheck
        Start-Sleep -s 10
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