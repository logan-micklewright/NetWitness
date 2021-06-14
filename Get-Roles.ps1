

$mongoCreds = Get-Credential -Message "Enter Mongo password" -UserName "deploy_admin"
$mongoPass = $mongoCreds.GetNetworkCredential().Password

$headUnit = Read-Host -Prompt "Enter the IP of the head unit"

$rawPermissions = ssh root@$headUnit "mongo security-server -u deploy_admin -p $mongoPass --authenticationDatabase admin --quiet --eval \`"printjson( db.getCollection(`'permission`').find({},{ _id: 1 }).toArray() )\`""
$rawRoles = ssh root@$headUnit "mongo security-server -u deploy_admin -p $mongoPass --authenticationDatabase admin --quiet --eval \`"printjson(  db.getCollection('role').find({  }, { _id: 1, permissions: 1}).toArray() )\`""

$roles = $rawRoles | ConvertFrom-Json

$permissionsList = $rawPermissions | ConvertFrom-Json | Select-Object -ExpandProperty _id

$formattedRoles = @()

foreach ($role in $roles){
    $permissionObject = [PSCustomObject]@{
        Name = $role._id
    }
    foreach ($permission in ($permissionsList | Sort-Object)){
        $permissionEnabled = $false
        if($permissionObject.Name -eq "Administrators" -or $role.permissions -contains $permission){
            $permissionEnabled = $true
        }
        $permissionObject | Add-Member -MemberType NoteProperty -Name $permission -Value $permissionEnabled
    }
    $formattedRoles += $permissionObject
}


$formattedRoles | Export-Csv -Path ./NetWitnessRoles.csv