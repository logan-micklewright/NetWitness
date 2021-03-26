#Get a list of all known services and hosts using the orchestration client on the head unit
$headUnit = Read-Host -Prompt "Enter the IP of the head unit"
$rawHosts = ssh root@$headUnit 'orchestration-cli-client -l'


#The last two lines returned are always messages about the status rather than actual hosts or services, strip them or it breaks proper parsing of the rest
$rawHosts = $rawHosts[0..($rawHosts.Length-3)]

#Output from the orchestration client unfortunately has a lot of extra junk in front of it, need to strip that to get the actual data, so chop the beginning of each line up to the part we care about
$i=0
while($i -lt $rawHosts.Length){
    $rawHosts[$i] = $rawHosts[$i].Substring(108)
    $i++
}


#Now that the output is cleaned a little it can be parsed into a usable format, it's obviously not a csv file but format is close enough the csv import commandlet parses it nicely
$servers = $rawHosts | ConvertFrom-Csv -Header ID, IP, Name, Version
$servers | Add-Member -NotePropertyName "ApplianceUpdated" -NotePropertyValue "No"
foreach($server in $servers){
    $server.ID = $server.ID.Substring(3)
    $server.IP = $server.IP.Substring(5)
    $server.Name = $server.Name.Substring(5)
    $server.Version = $server.Version.Substring(8)
}

$servers | Export-Csv -Path .\NW-ServerList.csv