#Generate status report
$IPAddresses = Import-Csv '.\Addresses.csv'

#Prompt user for credentials so that we don't have to store in the script
$currentCred = Get-Credential -Message "Provide credentials to connect to iDRAC"
$user = $CurrentCred.GetNetworkCredential().Username
$pass = $CurrentCred.GetNetworkCredential().Password

$threadSafeDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
$i=1
$j = $IPAddresses.Count

foreach ($server in $IPAddresses) {
	#Need to check for each field set during the initial config, password, name, syslog, firmware version, bios version, perc version, iso mounted.
	#No way to query the password directly but if the commands run that means the password used was correct, any failure to return output likely means the password never got correctly configured on that host
	$IP = $server.IP
	Write-Output "Querying $IP"

	$dracName = racadm -r $IP -u $user -p $pass get iDRAC.NIC.DNSRacName --nocertwarn
	$syslogServer = racadm -r $IP -u $user -p $pass get iDRAC.Syslog.Server1 --nocertwarn
	$syslogEnabled = racadm -r $IP -u $user -p $pass get iDRAC.Syslog.SysLogEnable --nocertwarn
	$dracVersion = racadm -r $IP -u $user -p $pass get iDRAC.Info.version --nocertwarn
	$biosVersion = racadm -r $IP -u $user -p $pass get BIOS.SysInformation.SystemBiosVersion --nocertwarn
	$storageVersion = racadm -r $IP -u $user -p $pass Storage get controllers -o -p FirmwareVersion --nocertwarn
	$remoteImage = racadm -r $IP -u $user -p $pass remoteimage -s --nocertwarn
	$powerStatus = racadm -r $IP -u $user -p $pass get System.Power.Status --nocertwarn
	
	#Clean up output
	#racadm returns a bunch of garbage here, because it's multiple lines it's stored as an array, each element in the array is a single line stored as a string
	#using some string indexing and splitting we clean it up into just the values we want and build a PS object out of it that will give nicer output options
	
	$serverState = "Unknown"
	if($powerStatus[4] -eq 0){
		$serverState = "Powered Off"
	}elseif($powerStatus[4] -eq 1){
		$serverState = "Powered On"
	}

	$syslogEnabled = $syslogEnabled[6].Substring($syslogEnabled[6].LastIndexOf('=')+1)
	if($syslogEnabled -eq "Enabled"){
		$syslogEnabled = "Yes"
	}else{
		$syslogEnabled = "No"
	}


	$statusReport = New-Object -TypeName PSObject -Property @{
		iDRACName = $dracName[6].Substring($dracName[6].LastIndexOf('=')+1)
		iDRACVersion = $dracVersion[6].Substring($dracVersion[6].LastIndexOf('=')+1)
		BIOSVersion = $biosVersion[6].Substring($biosVersion[6].LastIndexOf('=')+1)
		PERCVersion = $storageVersion[5].Substring($storageVersion[5].LastIndexOf('=')+2)
		SyslogServer = $syslogServer[6].Substring($syslogServer[6].LastIndexOf('=')+1)
		SyslogEnabled = $syslogEnabled
		RemoteImage = $remoteImage[4]
		RemoteImagePath = $remoteImage[10]
		PowerState = $serverState
	} | Select iDRACName, iDRACVersion, BIOSVersion, PERCVersion, SyslogServer, SyslogEnabled, RemoteImage, RemoteImagePath, PowerState

	$threadSafeDictionary.TryAdd($IP, $statusReport) | Out-Null
	$i = $threadSafeDictionary.Count
	Write-Output "Completed $i of $j"
}
foreach ($key in $threadSafeDictionary.Keys){
	Write-Output "Report for $key :"
	$threadSafeDictionary[$key]
	Write-Output "
	"
}