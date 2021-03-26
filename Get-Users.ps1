#IMPORTANT: This relies on the presence of the getUsers.sh and getUsers.js scripts on the NetWitness server or it will not return any data

$mongoCreds = Get-Credential -Message "Enter Mongo password" -UserName "deploy_admin"
$mongoPass = $mongoCreds.GetNetworkCredential().Password

$headUnit = Read-Host -Prompt "Enter the IP of the head unit"

ssh root@$headunit "/root/getUsers.sh $mongoPass"
scp root@${headunit}:/root/NetWitnessUsers.json ./

$rawUsers = Get-Content -Path NetWitnessUsers.json

$users = $rawUsers | ConvertFrom-Json

foreach($user in $users){
    $timestamp = $user.successfulLoginTimestamps.Substring(0,10)
    $user.successfulLoginTimestamps = Get-Date -UnixTimeSeconds $timestamp
}

$users | ConvertTo-Csv | Out-File -FilePath NetWitnessUsers.csv
