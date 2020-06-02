Import-Module .\NetWitness-Ops
Import-Module .\iDrac-Ops

#Get a list of servers to build, prompt user to choose individual IP address or csv file


#Establish some baseline values, we don't want to bug the user after this point, should be an unattended, automated, build process

#Now we're going to start interacting with the NW API for the remainder of the config so let's get some creds to work with
$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

#Prompt the user to select a reference broker, concentrator, decoder, and logdecoder
$refBroker = $NWServices | Where-Object {$_.Name -eq "broker"} | Out-GridView -PassThru -Title 'Select Reference Broker'
$brokerRoles = Get-NWRoles -NWService $refBroker -apiCreds $apiCreds

$refConcentrator = $NWServices | Where-Object {$_.Name -eq "concentrator"} | Out-GridView -PassThru -Title 'Select Reference Concentrator'
$concentratorRoles = Get-NWRoles -NWService $refConcentrator -apiCreds $apiCreds

$refDecoder = $NWServices | Where-Object {$_.Name -eq "decoder"} | Out-GridView -PassThru -Title 'Select Reference Decoder'
$decoderRoles = Get-NWRoles -NWService $refDecoder -apiCreds $apiCreds

$refLogDecoder = $NWServices | Where-Object {$_.Name -eq "logdecoder"} | Out-GridView -PassThru -Title 'Select Reference Log Decoder'
$logDecoderRoles = Get-NWRoles -NWService $refLogDecoder -apiCreds $apiCreds

#Call iDrac setup script, should handle everything up through mounting the ISO, pass the list of IPs to it

#At this stage the server boots and the image is installed, it takes an hour, maybe figure out a way for the script to check status every x minutes and then proceed once imaging is complete

#Now the OS needs to be configured, I haven't yet automated most of those tasks, on my todo list, so pause with the option to resume once OS has been configured

#Then we're into the NW config, push services with orchestration client, install updates. Once services are installed, build out the objects to use for the rest of the config

#Enable SSL on the rest api
foreach($service in $NWServices){
    Set-NWSSL -NWService $service -apiCreds $apiCreds    
}
foreach($server in $NWHosts){
    $service = New-Object -TypeName psobject
    $service | Add-Member -MemberType Noteproperty -Name Name -Value "Appliance"
    $service | Add-Member -MemberType Noteproperty -Name IP -Value $server.IP
    $service | Add-Member -MemberType Noteproperty -Name Port -Value "50106"
    Set-NWSSL -NWService $service -apiCreds $apiCreds
}

#Change the admin password
$newCreds = Get-Credential -Message "Enter desired new admin password" -UserName "admin"
foreach($service in $NWServices){
    Set-NWPassword -NWService $service -apiCreds $apiCreds -newCreds $newCreds    
}
foreach($server in $NWHosts){
    $service = New-Object -TypeName psobject
    $service | Add-Member -MemberType Noteproperty -Name Name -Value "Appliance"
    $service | Add-Member -MemberType Noteproperty -Name IP -Value $server.IP
    $service | Add-Member -MemberType Noteproperty -Name Port -Value "50106"
    Set-NWPassword -NWService $service -apiCreds $apiCreds -newCreds $newCreds 
}

#Now that all services are update the apiCreds are the newCreds from here on out
$apiCreds = $newCreds

#Replicate roles

foreach($service in $NWServices){
    if($service.Name -eq "broker"){
        $roles = $brokerRoles
    }elseif($service.Name -eq "concentrator"){
        $roles = $concentratorRoles
    }elseif($service.Name -eq "decoder"){
        $roles = $decoderRoles
    }elseif($service.Name -eq "logdecoder"){
        $roles = $logDecoderRoles
    }else{
        continue
    }
    Set-NWRoles -apiCreds $apiCreds -NWService $service -roles $roles
}


#Configure storage

#Configure aggregation/capture

#Produce a verification report for all hosts once the build is complete
