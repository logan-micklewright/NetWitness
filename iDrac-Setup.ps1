<#
iDRAC Configuration script by Logan Micklewright, 02/17/2020

Simple configuration menu to automate standard tasks we need to complete on each iDRAC during server build
#>

#Prompt user for credentials so that we don't have to store in the script

Import-Module iDrac-Ops

$currentCred = Get-Credential -Message "Provide credentials to connect to iDRAC" -UserName "root"
$user = $CurrentCred.GetNetworkCredential().Username
$pass = $CurrentCred.GetNetworkCredential().Password

function Show-IPChoices {
    $Title = 'iDRAC Configuration Tool'
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Single IP."
    Write-Host "2: List of IPs from file"
}

function Show-Menu {
    $Title = 'iDRAC Configuration Tool'
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Set password."
    Write-Host "2: Set iDRAC name"
    Write-Host "3: Configure Syslog"
    Write-Host "4: Install Updates"
    Write-Host "5: Mount ISO"
    Write-Host "6: UnMount ISO"
    Write-Host "7: Powercycle"
    Write-Host "8: Status Report"
    Write-Host "L: List Servers"
    Write-Host "S: Switch Servers"
    Write-Host "Q: Press 'Q' to quit."
}

Add-Type -AssemblyName System.Windows.Forms

#Display a menu so the user can choose to work with a single machine or import multiple from a file
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

$j=$IPAddresses.Count

#Main part of the script begins here, display a menu for the user and just keep looping back to the menu after each action until the user choose 'q'
#In all cases accept the firmware update we will process commands on 10 machines at a time, for updates we only do 3 at a time since the file is being uploaded and too many parallel uploads kill connection speed and make the whole thing take longer
do {
    Show-Menu
    $selection = Read-Host "Please make a selection"

    #We're going to process multiple hosts at once using the new Foreach-Object -Parallel option that was introduced in PS7. In order to track progress we need a thread safe variable we can write back to from each instance of the loop
    $threadSafeDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()

    #Based on the users choice in the menu carry out the particular action
    switch ($selection) {
        '1' {
            #Set the iDRAC password
            $NewCred = Get-Credential -Message "Provide desired new login info for iDRAC" -UserName 'root'
            #Can delete this line as soon as I've ported everything else away from racadm
            $NewPassword = $newCreds.GetNetworkCredential().Password        

            $IPAddresses | ForEach-Object -Parallel {
                Set-iDracPassword -idracIP $_.IP -apiCreds $using:currentCred -newCreds $using:NewCred                

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10

            #In the event that we change password we need to set the current password used by the script to the new password just set or any subsequent menu actions will fail
            $currentCred = $NewCred
            #Can delete this line as soon as I've ported everything else away from racadm
            $pass = $NewPassword
        } 
        '2' {
            #Set the iDRAC name
            $i=1
            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                $ThisName = $_.Name
                racadm -r $ThisIP -u $using:user -p $using:pass set iDRAC.NIC.DNSRacName "idrac-$ThisName" --nocertwarn

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
        } 
        '3' {
            #Configure syslog
            $i=1
            $syslogServer = Read-Host -Prompt "Enter IP address of syslog server"
            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                racadm -r $ThisIP -u $using:user -p $using:pass set iDRAC.Syslog.Server1 $syslogServer --nocertwarn
                racadm -r $ThisIP -u $using:user -p $using:pass set iDRAC.Syslog.SysLogEnable '1' --nocertwarn

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
        } 
        '4' {
            #Install update file
            $i=1
        
            $FileChooser = New-Object -TypeName System.Windows.Forms.OpenFileDialog
            $FileChooser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
            $FileChooser.filter = "Executable (*.exe)| *.exe|iDRAC-Firmware (*.d9)|*.d9"
            $FileChooser.Title = "Choose file containing update to install"
            $FileChooser.ShowDialog()
            $FilePath = $FileChooser.Filename

            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                racadm -r $ThisIP -u $using:user -p $using:pass update -f $using:FilePath --nocertwarn

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 3
        } 
        '5' {
            #Mount iso file
            $i=1
            $ISO_Creds = Get-Credential -Message "Provide credentials for ISO Share"
            $ISO_User_Pass = $ISO_Creds.GetNetworkCredential().Password
            $ISO_User_Name = $ISO_Creds.GetNetworkCredential().Username
            $share = Read-Host -Prompt "Enter NFS share path that you want to mount the image from. Should be in the format: 1.2.3.4:/\folder/\filename"
            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                racadm -r $ThisIP -u $using:user -p $using:pass remoteimage -c -u $using:ISO_User_Name -p $using:ISO_User_Pass -l $using:share --nocertwarn

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
        }
        '6' {
            #Unmount the mounted iso
            $i=1
            $IPAddresses | ForEach-Object -Parallel {
                Remove-VirtualMedia -idracIP $_.IP -apiCreds $using:currentCred

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
        }
        '7' {
            #Powercycle the server (needed to install BIOS/Firmware updates once they're queued)
            $i=1
            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                racadm -r $ThisIP -u $using:user -p $using:pass serveraction powercycle --nocertwarn

                #This is purely for tracking status so that we have some output showing how many hosts have been processed so far
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($_.IP, $_) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
        }
        '8' {
            #Generate status report
            $i=1
            $IPAddresses | ForEach-Object -Parallel {
                $ThisIP = $_.IP
                #Need to check for each field set during the initial config, password, name, syslog, firmware version, bios version, perc version, iso mounted.
                #No way to query the password directly but if the commands run that means the password used was correct, any failure to return output likely means the password never got correctly configured on that host
                Write-Output "Querying $ThisIP"

                $systemInfo = Get-SystemInfo -idracIP $ThisIP -apiCreds $using:currentCred

                $powerStatus = $systemInfo.PowerState
                $syslogServer = racadm -r $ThisIP -u $using:user -p $using:pass get iDRAC.Syslog.Server1 --nocertwarn
                $syslogEnabled = racadm -r $ThisIP -u $using:user -p $using:pass get iDRAC.Syslog.SysLogEnable --nocertwarn
                $dracVersion = Get-iDRACVersion -idracIP $ThisIP -apiCreds $using:currentCred
                $biosVersion = $systemInfo.BiosVersion
                $storageVersion = Get-StorageControllerVersion -idracIP $ThisIP -apiCreds $using:currentCred
                $remoteImage = Get-VirtualMediaStatus -idracIP $ThisIP -apiCreds $using:currentCred
                $dracName = Get-iDracName -idracIP $ThisIP -apiCreds $using:currentCred
                


                $statusReport = New-Object -TypeName PSObject -Property @{
                    iDRACName = $dracName
                    iDRACIP = $ThisIP
                    iDRACVersion = $dracVersion
                    BIOSVersion = $biosVersion
                    PERCVersion = $storageVersion
                    SyslogServer = $syslogServer[6].Substring($syslogServer[6].LastIndexOf('=')+1)
                    SyslogEnabled = $syslogEnabled
                    RemoteImage = $remoteImage.ConnectedVia
                    RemoteImagePath = $remoteImage.Image
                    PowerState = $powerStatus
                } | Select-Object iDRACName, iDRACIP, iDRACVersion, BIOSVersion, PERCVersion, SyslogServer, SyslogEnabled, RemoteImage, RemoteImagePath, PowerState
                $dict = $using:threadSafeDictionary
                $dict.TryAdd($ThisIP, $statusReport) | Out-Null
                $i = $dict.Count
                Write-Output "Completed $i of $using:j"
            } -ThrottleLimit 10
            #Write the output to the screen and file once all hosts have been queried
            $today = Get-Date -Format "yyyyMMdd"
            $reportName = "iDracReport-$today.csv"
            foreach ($key in $threadSafeDictionary.Keys){
                Write-Output "Report for $key :"
                $threadSafeDictionary[$key]
                $threadSafeDictionary[$key] | Export-Csv -Path $reportName -Append
                Write-Output "
                "
            }
        }
        'S' {
            $FileChooser = New-Object -TypeName System.Windows.Forms.OpenFileDialog
            $FileChooser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
            $FileChooser.filter = "Comma Seperated Value (*.csv)| *.csv"
            $FileChooser.Title = "Choose file containing names and IP addresses"
            $FileChooser.ShowDialog()
            $FilePath = $FileChooser.Filename
            $IPAddresses = Import-Csv $FilePath
        }
        'L' { 
            $IPAddresses
        }
    }
    if($selection -eq 'q'){break}
    pause
 }
 until ($selection -eq 'q')
