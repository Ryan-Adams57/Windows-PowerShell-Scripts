# Get-WindowsKey.ps1
# Retrieves the Windows product key stored in BIOS/UEFI (OA3 key)

Write-Host "--- Retrieving Windows Key from BIOS ---" -ForegroundColor Cyan
$WindowsKey = (Get-CimInstance -Query 'SELECT * FROM SoftwareLicensingService').OA3xOriginalProductKey

if ($WindowsKey) {
    Write-Host "Windows Product Key: $WindowsKey" -ForegroundColor Green
} else {
    Write-Host "No OA3 product key found in BIOS." -ForegroundColor Yellow
}
