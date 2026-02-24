<#
.SYNOPSIS
Keeps two directories in sync, copying updated files from source to destination.
.DESCRIPTION
Basic file replication utility. Does not handle versioning or conflicts like Git.
#>

$Source = "C:\SourceFolder"
$Destination = "D:\DestinationFolder"

# Copy updated or new files only
Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {
    $TargetPath = $_.FullName.Replace($Source, $Destination)
    $TargetDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
    if (-not (Test-Path $TargetPath) -or (Get-Item $_.FullName).LastWriteTime -gt (Get-Item $TargetPath).LastWriteTime) {
        Copy-Item -Path $_.FullName -Destination $TargetPath -Force
    }
}
