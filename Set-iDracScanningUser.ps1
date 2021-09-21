Import-Module ./iDrac-Ops

$role = "ReadOnly"
$userId = "3"
$userName = Read-Host "What username would you like to use"

$FileChooser = New-Object -TypeName System.Windows.Forms.OpenFileDialog
$FileChooser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$FileChooser.Title = "Choose file containing names and IP addresses"
$FileChooser.ShowDialog()
$FilePath = $FileChooser.Filename
$IPs = Import-Csv $FilePath

$apiCreds = Get-Credential -UserName "root"
$newCreds = Get-Credential -UserName $userName

foreach($ip in $IPs){
    $idracIP = $ip.IP
    Write-Host "Adding user to $idracIP"
    Add-iDracUser -idracIP $idracIP -apiCreds $apiCreds -newCreds $newCreds -userName $userName -role $role -userId $userId
}
