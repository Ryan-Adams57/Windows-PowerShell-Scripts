# Enable God Mode in Windows 10/11

# Get the current user's Desktop path
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Define the God Mode folder name
$godModeFolderName = "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"

# Combine full path
$fullPath = Join-Path -Path $desktopPath -ChildPath $godModeFolderName

# Check if the folder already exists
if (Test-Path $fullPath) {
    Write-Host "God Mode folder already exists on your Desktop." -ForegroundColor Yellow
}
else {
    # Create the God Mode folder
    New-Item -Path $fullPath -ItemType Directory | Out-Null
    Write-Host "God Mode has been successfully enabled on your Desktop." -ForegroundColor Green
}

Write-Host "You can now open it from your Desktop."
