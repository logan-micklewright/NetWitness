Import-Module .\NetWitness-Ops
Import-Module .\iDrac-Ops

#Very much still a work in progress. I laid out the various sections that would be needed, most of them are implemented in stand-alone scripts I've already written, but I hope to pull it all together at some point

#Get a list of servers to build, prompt user to choose individual IP address or csv file
function Show-IPChoices {
    $Title = 'NetWitness Server Build Tool'
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Single IP."
    Write-Host "2: List of IPs from file"
}

Add-Type -AssemblyName System.Windows.Forms

#If importing from file the csv MUST have a column titled IP and a column titled Name, additional columns are allowed but ignored by the script
#If user enters a single IP the script builds it into a PSObject simply to match the format that is created when a csv is imported, making the rest of the script simpler since is it always working off the same format of input data
Show-IPChoices
$selection = Read-Host "Please make a selection"
switch ($selection) {
    '1' {
        $IP = Read-Host "IP Address"
        $MachineName = Read-Host "Host Name"
        $IPAddresses = New-Object -TypeName psobject
        $IPAddresses | Add-Member -MemberType NoteProperty -Name IP -Value $IP
        $IPAddresses | Add-Member -MemberType NoteProperty -Name Name -Value $MachineName
    }
    '2' {
        $FileChooser = New-Object -TypeName System.Windows.Forms.OpenFileDialog
        $FileChooser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        $FileChooser.filter = "Comma Seperated Value (*.csv)| *.csv"
        $FileChooser.Title = "Choose file containing names and IP addresses"
        $FileChooser.ShowDialog()
        $FilePath = $FileChooser.Filename
        $IPAddresses = Import-Csv $FilePath
    }
}

#Establish some baseline values, we don't want to bug the user after this point, should be an unattended, automated, build process
$NWHeadUnit = Read-Host -Prompt "Enter the IP address of the NetWitness Head Unit"
$apiCreds = Get-Credential -Message "Enter default Admin password to connect" -UserName "admin"
$newCreds = Get-Credential -Message "Enter desired new admin password to set during build" -UserName "admin"

$NWHosts = Get-NWHosts -NWHost $NWHeadUnit
$NWServices = Get-NWServices -NWHost $NWHeadUnit

#Prompt the user to select which service types they're building and select a reference broker, concentrator, decoder, and logdecoder as needed
$title    = 'Choose'
$question = 'Are you configuring any Broker services?'
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    $refBroker = $NWServices | Where-Object {$_.Name -eq "broker"} | Out-GridView -PassThru -Title 'Select Reference Broker'
    $brokerRoles = Get-NWRoles -NWService $refBroker -apiCreds $apiCreds
} else {
    Write-Host 'No Brokers'
}

$question = 'Are you configuring any Concentrator services?'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    $refConcentrator = $NWServices | Where-Object {$_.Name -eq "concentrator"} | Out-GridView -PassThru -Title 'Select Reference Concentrator'
    $concentratorRoles = Get-NWRoles -NWService $refConcentrator -apiCreds $apiCreds
} else {
    Write-Host 'No Concentrators'
}

$question = 'Are you configuring any Decoder services?'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    $refDecoder = $NWServices | Where-Object {$_.Name -eq "decoder"} | Out-GridView -PassThru -Title 'Select Reference Decoder'
    $decoderRoles = Get-NWRoles -NWService $refDecoder -apiCreds $apiCreds
} else {
    Write-Host 'No Decoders'
}

$question = 'Are you configuring any Log Decoder services?'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    $refLogDecoder = $NWServices | Where-Object {$_.Name -eq "logdecoder"} | Out-GridView -PassThru -Title 'Select Reference Log Decoder'
    $logDecoderRoles = Get-NWRoles -NWService $refLogDecoder -apiCreds $apiCreds
} else {
    Write-Host 'No Log Decoders'
}

#Call iDrac setup script, should handle everything up through mounting the ISO, pass the list of IPs to it

#At this stage the server boots and the image is installed, it takes an hour, maybe figure out a way for the script to check status every x minutes and then proceed once imaging is complete

#Now the OS needs to be configured, this is mostly handled by Salt but the nwsetup-tui must be called. The catch is that the IP address isn't set yet, so usually we do this through the iDRAC remote console, how to automate?

#Then we're into the NW config, push services with orchestration client, install updates. Once services are installed, build out the objects to use for the rest of the config
foreach($server in $NewHosts){
    New-NWHost -NWHeadUnit $NWHeadUnit -nodeIP $server.IP -NWHostName - $server.Name
}
foreach($service in $NewServices){
    New-NWService -serviceType $service.Name -nodeIP $service.IP -NWHeadUnit $NWHeadUnit
    Update-NWHost -nodeIP $service.IP -NWHeadUnit $NWHeadUnit
}


#Enable SSL on the rest api
foreach($service in $NewServices){
    Set-NWSSL -NWService $service -apiCreds $apiCreds    
}
foreach($server in $NewHosts){
    $service = New-Object -TypeName psobject
    $service | Add-Member -MemberType Noteproperty -Name Name -Value "Appliance"
    $service | Add-Member -MemberType Noteproperty -Name IP -Value $server.IP
    $service | Add-Member -MemberType Noteproperty -Name Port -Value "50106"
    Set-NWSSL -NWService $service -apiCreds $apiCreds
}

#Change the admin password

foreach($service in $NewServices){
    Set-NWPassword -NWService $service -apiCreds $apiCreds -newCreds $newCreds    
}
foreach($server in $NewHosts){
    $service = New-Object -TypeName psobject
    $service | Add-Member -MemberType Noteproperty -Name Name -Value "Appliance"
    $service | Add-Member -MemberType Noteproperty -Name IP -Value $server.IP
    $service | Add-Member -MemberType Noteproperty -Name Port -Value "50106"
    Set-NWPassword -NWService $service -apiCreds $apiCreds -newCreds $newCreds 
}

#Now that all services are update the apiCreds are the newCreds from here on out
$apiCreds = $newCreds

#Replicate roles
foreach($service in $NewServices){
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
foreach($service in $NewServices){
    Set-NWStorage -nodeIP $service.IP -serviceType $service.Name -apiCreds $apiCreds
}


#Configure aggregation/capture

#If decoder or log decoder, install warehouse connector

#Install InsightVM Agent


#Produce a verification report for all hosts once the build is complete
