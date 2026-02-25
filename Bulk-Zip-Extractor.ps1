# Ask the user for the source directory containing the zip files
$sourceDirectory = Read-Host "Please enter the source folder path"

# Ask the user for the destination directory where the unzipped files will be placed
$destinationDirectory = Read-Host "Please enter the destination folder path"

# Ensure the destination directory exists
if (-not (Test-Path -Path $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
}

# Get all zip files from the source directory
$zipFiles = Get-ChildItem -Path $sourceDirectory -Filter *.zip -Recurse

# Loop through each zip file and extract it to the destination directory
foreach ($zipFile in $zipFiles) {
    # Create a subfolder in the destination directory with the same name as the zip file (without extension)
    $subfolder = Join-Path -Path $destinationDirectory -ChildPath $zipFile.BaseName
    New-Item -ItemType Directory -Path $subfolder -Force | Out-Null

    # Unzip the file to the subfolder
    Expand-Archive -LiteralPath $zipFile.FullName -DestinationPath $subfolder -Force
}

Write-Host "All files have been unzipped to $destinationDirectory"
