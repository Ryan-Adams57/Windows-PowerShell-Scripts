# ==========================================
# File Type Auto-Sort Script
# ==========================================

# 1️⃣ Path to folder to be cleaned
# IMPORTANT: Update this path if needed
$sourcePath = "C:\Users\PKUser\Downloads"

# Validate source path
if (-not (Test-Path $sourcePath)) {
    Write-Host "Source folder not found: $sourcePath" -ForegroundColor Red
    exit 1
}

# 2️⃣ File type mapping (edit as needed)
$groupMap = @{

    "Word"  = ".docx", ".doc", ".pdf", ".txt", ".ini"
    "Excel" = ".xlsx", ".xls", ".csv", ".scv", ".dbf"
    "PPT"   = ".pptx", ".ppt"
    "Image" = ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".avif", ".img"
    "Video" = ".mp4"
    "Audio" = ".mp3", ".wav", ".wma"
    "ZIP"   = ".zip", ".rar"
    "APP"   = ".exe", ".msi", ".apk"
    "Web"   = ".html", ".css", ".json", ".geojson", ".xml"
    "CAD"   = ".dxf", ".drawio", ".glb", ".onx", ".cmz", ".cur"
    "PBI"   = ".pbix"
    "Other" = ".download", ".shp", ".shx", ".prj", ".iqy", ".msapp"
}

# 3️⃣ Scan and move files
$files = Get-ChildItem -Path $sourcePath -File

foreach ($file in $files) {

    $fileExtension = $file.Extension.ToLower()
    $destinationFolder = $null

    # Determine destination folder
    foreach ($folderName in $groupMap.Keys) {
        if ($groupMap[$folderName] -contains $fileExtension) {
            $destinationFolder = Join-Path $sourcePath $folderName
            break
        }
    }

    # If no match found, skip file
    if (-not $destinationFolder) {
        continue
    }

    # Create folder if needed
    if (-not (Test-Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    }

    # Move file
    try {
        Move-Item -Path $file.FullName -Destination $destinationFolder -Force -ErrorAction Stop
        Write-Host "Moved: $($file.Name) -> $(Split-Path $destinationFolder -Leaf)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Failed: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Files sorted by type successfully." -ForegroundColor Green
