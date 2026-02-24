# Basic if statement example
if (3 -gt 1) {
    Write-Host "Three is greater than one"
}

# Example: create folder if it doesn't exist
$FolderPath = "C:\ExampleFolder"
if (-not (Test-Path $FolderPath)) {
    New-Item -Path $FolderPath -ItemType Directory
    Write-Host "Folder created at $FolderPath"
} else {
    Write-Host "Folder already exists"
}
