$scripts = Get-ChildItem -Filter *.ps1

foreach($script in $scripts){
    $name = $script.Name
    $newName = "$name.txt"
    Copy-Item -Path $name -Destination $newName
}