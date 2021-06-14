Import-Module NetWitness-Ops

function Build-Tree {
    param (
        [Parameter(Mandatory=$true, HelpMessage="A NW service object which should contain at least an IP and Port")]
        [System.Object] $NWService,

        [Parameter(Mandatory=$true, HelpMessage="The list to add the nodes to")]
        [System.Object] $ServerList,

        [Parameter(Mandatory=$true, HelpMessage="Provide a credential object used to authenticate to the API")]
        [pscredential] $apiCreds
    )
    $output = Get-Connections -NWService $NWService -apiCreds $apiCreds

    foreach ($node in $output.nodes) {
        $IP = $node.display.split(":")[0]
        $Port = $node.display.split(":")[1]
        $Name = Get-ServerName -NWService $NWService -apiCreds $apiCreds
        
        if($Port -eq "50003" -or $Port -eq "56003"){
            $ServiceType = "Broker"
            $Port = "50103"
        }elseif ($Port -eq "50005" -or $Port -eq "56005") {
            $ServiceType = "Concentrator"
            $Port = "50105"
        }elseif ($Port -eq "50004" -or $Port -eq "56004") {
            $ServiceType = "Decoder"
            $Port = "50104"
        }else{
            $ServiceType = "Invalid"
        }

        $ChildService = New-Object -TypeName psobject
        $ChildService | Add-Member -MemberType NoteProperty -Name IP -Value $IP
        $ChildService | Add-Member -MemberType NoteProperty -Name Port -Value $Port
        $ChildService | Add-Member -MemberType NoteProperty -Name ServiceType -Value $ServiceType
        $ChildService | Add-Member -MemberType NoteProperty -Name Name -Value $Name
        $ChildService | Add-Member -MemberType NoteProperty -Name Parent -Value $NWService.Name

        $ServerList += $ChildService

        if($ServiceType -eq "Broker" -or $ServiceType -eq "Concentrator"){
            Write-Host "Checking $Name for more nodes"
            Build-Tree -NWService $ChildService -ServerList $ServerList -apiCreds $apiCreds
        }

    }
    
}

$apiCreds = Get-Credential -Message "Enter current Admin password to connect" -UserName "admin"

$IP = Read-Host -Prompt "Enter hostname or IP of NW head unit to query"
$ServiceType = "Broker"
$Port = "50103"
$Service = New-Object -TypeName psobject
$Service | Add-Member -MemberType NoteProperty -Name IP -Value $IP
$Service | Add-Member -MemberType NoteProperty -Name Port -Value $Port
$Service | Add-Member -MemberType NoteProperty -Name ServiceType -Value $ServiceType

$HeadUnitName = Get-ServerName -NWService $Service -apiCreds $apiCreds
$Service | Add-Member -MemberType NoteProperty -Name Name -Value $HeadUnitName
$Service | Add-Member -MemberType NoteProperty -Name Parent -Value "HeadUnit"

$ServerList = @()
$ServerList += $Service

Build-Tree -NWService $Service -apiCreds $apiCreds -ServerList $ServerList

$ServerList