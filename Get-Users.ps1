#IMPORTANT: This relies on the presence of the getUsers.sh and getUsers.js scripts on the NetWitness server or it will not return any data

$mongoCreds = Get-Credential -Message "Enter Mongo password" -UserName "deploy_admin"
$mongoPass = $mongoCreds.GetNetworkCredential().Password

$headUnit = Read-Host -Prompt "Enter the IP of the head unit"

ssh root@$headunit "/root/getUsers.sh $mongoPass"
scp root@${headunit}:/root/NetWitnessUsers*.json ./

$rawgroups = ssh root@$headunit "grep 'sronetwitness' /etc/group"
$formattedGroups = @()

foreach ( $group in $rawgroups) {
    $groupObject = [PSCustomObject]@{
        Name = ($group.split(":x:"))[0]
        Users = ($group.split(":x:"))[1]
    }
    $formattedGroups += $groupObject

}

$rawUsers = Get-Content -Path NetWitnessUsers.json
$rawUsersNoLogin = Get-Content -Path NetWitnessUsersNoLogin.json

$users = $rawUsers | ConvertFrom-Json
$usersNoLogin = $rawUsersNoLogin | ConvertFrom-Json

foreach($user in $users){
    $timestamp = $user.successfulLoginTimestamps.Substring(0,10)
    $user.successfulLoginTimestamps = Get-Date -UnixTimeSeconds $timestamp
}

$users += $usersNoLogin
$users | Add-Member -MemberType NoteProperty -Name "Group" -Value "Unknown"

foreach($user in $users){
    foreach ($group in $formattedGroups) {
        if($group.Users -match $user._id){
            $user.Group = $group.Name
        }
    }
}

$users | ConvertTo-Csv | Out-File -FilePath NetWitnessUsers.csv
