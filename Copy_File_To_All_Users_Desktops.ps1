$Users = Get-ChildItem C:\Users -Directory | Where-Object { $_.Name -notin @("Administrator","Public","Default*") }

foreach($User in $Users){
    $Path = "C:\Users\$($User.Name)\Desktop"
    Copy-Item -Path "\\Path\To\Source\File.txt" -Destination "$Path\File.txt"
}
