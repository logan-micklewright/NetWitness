#IMPORTANT: This relies on the presence of the getRoles.sh and getRoles.js scripts on the NetWitness server or it will not return any data

$mongoCreds = Get-Credential -Message "Enter Mongo password" -UserName "deploy_admin"
$mongoPass = $mongoCreds.GetNetworkCredential().Password

$headUnit = Read-Host -Prompt "Enter the IP of the head unit"

ssh root@$headunit "/root/getRoles.sh $mongoPass"
scp root@${headunit}:/root/NetWitnessRoles.json ./

$rawRoles = Get-Content -Path NetWitnessRoles.json

$roles = $rawRoles | ConvertFrom-Json

$permissionsList = $roles | Where-Object {$_._id -eq 'All-Permissions-Not-Used'} | Select-Object -ExpandProperty permissions

$formattedRoles = @()

foreach ($role in $roles){
    $permissionObject = [PSCustomObject]@{
        Name = $role._id
    }
    foreach ($permission in $permissionsList){
        $permissionEnabled = $false
        if($permissionObject.Name -eq "Administrators"){
            $permissionEnabled = $true
        }
        if($role.permissions -contains $permission){
            $permissionEnabled = $true
        }
        $permissionObject | Add-Member -MemberType NoteProperty -Name $permission -Value $permissionEnabled
    }
    $formattedRoles += $permissionObject
}

$formattedRoles = $formattedRoles | %{$obj = new-object psobject; `
    $_.psobject.properties | Sort Name | `
        %{Add-Member -Inp $obj NoteProperty $_.Name $_.Value}; $obj}

     
$formattedRoles | ConvertTo-Csv | Out-File -FilePath NetWitnessRoles.csv