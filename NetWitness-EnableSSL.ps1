$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"
$updateURI = "/rest/config/ssl?msg=set&force-content-type=text/plain&value=on"

$appliancePort="50106"

#Get a list of all known services and hosts using the orchestration client on the head unit
$headUnit = Read-Host -Prompt "Enter the IP of the head unit"
$rawServices = ssh root@$headUnit 'orchestration-cli-client -s'
$rawHosts = ssh root@$headUnit 'orchestration-cli-client -l'


#The last two lines returned are always messages about the status rather than actual hosts or services, strip them or it breaks proper parsing of the rest
$rawServices = $rawServices[0..($rawServices.Length-3)]
$rawHosts = $rawHosts[0..($rawHosts.Length-3)]

#Output from the orchestration client unfortunately has a lot of extra junk in front of it, need to strip that to get the actual data, so chop the beginning of each line up to the part we care about
$i=0
while($i -lt $rawServices.Length){
    $rawServices[$i] = $rawServices[$i].Substring(111)
    $i++
}
$i=0
while($i -lt $rawHosts.Length){
    $rawHosts[$i] = $rawHosts[$i].Substring(108)
    $i++
}


#Now that the output is cleaned a little it can be parsed into a usable format
$servers = $rawHosts | ConvertFrom-Csv -Header ID, IP, Name, Version
$servers | Add-Member -NotePropertyName "ApplianceUpdated" -NotePropertyValue "No"
foreach($server in $servers){
    $server.ID = $server.ID.Substring(3)
    $server.IP = $server.IP.Substring(5)
    $server.Name = $server.Name.Substring(5)
    $server.Version = $server.Version.Substring(8)
}

#When the services are being parsed from the raw input there's actually a column for TLS but I don't care about that so I'm naming the column port and using it to hold the port number value once I split it from the IP string below
#It's not necessary, just a little faster than removing the unneeded object property and then adding a new one
$NWservices = $rawServices | ConvertFrom-Csv -Header ID, Service, IP, Port

foreach($service in $NWservices){
    $service.ID = $service.ID.Substring(3)
    $service.Service = $service.Service.Substring(5)
    $service.IP = $service.IP.Substring(5)
    $IPandPort = $service.IP.split(":")
    $service.IP = $IPandPort[0]
    $service.Port = $IPandPort[1]
    $thisServer = $servers.Where{$_.IP -eq $service.IP}  


    #Now that we have a nice clean object with all the properties for each service we can proceed to connect to them
    #Not every service type has to be updated so lets look at just the types we care about
    if(($service.Service -eq "broker") -or ($service.Service -eq "concentrator") -or ($service.Service -match "decoder") -or ($service.Service -eq "log-collector") -or ($service.Service -eq "warehouse-connector")){
        $thisIP = $service.IP
        $thisPort = $service.Port
        switch($thisPort){
            '56001'{$thisPort="50101"}
            '56002'{$thisPort="50102"}
            '56003'{$thisPort="50103"}
            '56004'{$thisPort="50104"}
            '56005'{$thisPort="50105"}
            '56020'{$thisPort="50120"}
        }
        $thisService = $service.Service
        $thisService = $thisService -replace '-',''
        $thisName = $thisServer.Name
        $serviceURI = "http://$thisIP"+":"+$thisPort+$updateURI
        Write-Host "Updating $thisService on $thisName"
        Invoke-RestMethod -Uri "$serviceURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication

        $serviceStopURI="http://$thisIP"+":"+$appliancePort+"/appliance?msg=stop&force-content-type=text/plain&service=$thisService"
        $serviceStartURI="http://$thisIP"+":"+$appliancePort+"/appliance?msg=start&force-content-type=text/plain&service=$thisService"
        
        Invoke-RestMethod -Uri "$serviceStopURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
        Start-Sleep -s 10
        Invoke-RestMethod -Uri "$serviceStartURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication

        #The appliance service on each host also needs updated but because hosts run multiple services and we don't want to try and update it mutiple times we'll check to see if we've already done this one
        #In order for this to work an extra field has been added to the servers while they were being parsed called ApplianceUpdated which is set to no by default and then updated to yes the first time this block runs
        if($thisServer.ApplianceUpdated -eq "No"){
            $applianceURI = "http://$thisIP"+":"+$appliancePort+$updateURI
            $serviceRestartURI = "http://$thisIP"+":"+$appliancePort+"/sys?msg=shutdown&force-content-type=text/plain&reason=Enable%20SSL"
            Write-Host "Updating Appliance Service on $thisName"
            Invoke-RestMethod -Uri "$applianceURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
            Invoke-RestMethod -Uri "$serviceRestartURI" -Credential $apiCreds -SkipCertificateCheck -AllowUnencryptedAuthentication
            Start-Sleep -s 15
            foreach($s in $thisServer){
                $s.ApplianceUpdated = "Yes"
                }
        }
    }
}
