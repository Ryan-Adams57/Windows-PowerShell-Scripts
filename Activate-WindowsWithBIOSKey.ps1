# Activate-WindowsWithBIOSKey.ps1
# Activates Windows using the OA3 product key stored in BIOS/UEFI
# Must be run as Administrator

Write-Host "--- Activating Windows with BIOS Key ---" -ForegroundColor Cyan

$ProdKey = (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey

if ($ProdKey) {
    Write-Host "Found product key. Activating..." -ForegroundColor Green
    cmd /c "C:\Windows\System32\slmgr.vbs //b /ipk $ProdKey"
    Write-Host "Activation command sent. Check Windows activation status." -ForegroundColor Green
} else {
    Write-Host "No OA3 product key found in BIOS. Cannot activate." -ForegroundColor Red
}
