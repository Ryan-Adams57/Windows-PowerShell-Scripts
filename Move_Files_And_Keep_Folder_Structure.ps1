<#
.SYNOPSIS
Moves files from source to destination while preserving folder structure.
.DESCRIPTION
Useful for archival, cleanup, or reorganizing directories.
.NOTES
Tested in a single environment, use at your own risk.
#>

$Source = "C:\SourceFolder"
$Destination = "D:\DestinationFolder"

# Example: Move all .txt files, preserving structure
Get-ChildItem -Path $Source -Recurse -File -Filter "*.txt" | ForEach-Object {
    $TargetPath = $_.FullName.Replace($Source, $Destination)
    $TargetDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
    Move-Item $_.FullName -Destination $TargetPath
}
