# Prompt the user for source and destination folders
$SourceFolder = Read-Host "Enter the source folder"
$DestinationFolder = Read-Host "Enter the destination folder for zipped files"

# Check if the source folder exists
if (-Not (Test-Path $SourceFolder -PathType Container)) {
    Throw "The source directory $SourceFolder does not exist, please specify an existing directory"
}

# Check if the destination folder exists, if not, create it
if (-Not (Test-Path $DestinationFolder -PathType Container)) {
    New-Item -ItemType Directory -Path $DestinationFolder | Out-Null
}

$date = Get-Date -format "yyyy-MM-dd"
$folders = Get-ChildItem -Path $SourceFolder -Directory

foreach ($folder in $folders) {
    $dirPath = $folder.FullName
    $destinationPath = Join-Path $DestinationFolder "$($folder.Name)_$date.zip"
    Compress-Archive -Path $dirPath -CompressionLevel 'Fastest' -DestinationPath $destinationPath
}

Write-Host "Compressed!!"
