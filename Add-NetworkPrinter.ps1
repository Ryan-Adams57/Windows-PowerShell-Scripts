# Add-NetworkPrinter.ps1
# Adds a printer port and printer to a remote PC or server
# Must be run as Administrator with rights on the target machine

# --- Configuration ---
$TargetPC    = "<PC/Server>"          # e.g., "PRINTSERVER01"
$IPAddress   = "<IP Address>"         # e.g., "192.168.1.100"
$PrinterName = "<Name of Printer>"    # e.g., "HP LaserJet 400"
$DriverName  = "<Exact Driver Name>"  # e.g., "HP Universal Printing PCL 6"
$PortName    = $IPAddress             # Port name (often same as IP)
$Comment     = "<Comment>"            # e.g., "IT Department Printer"
$Location    = "<Location Info>"      # e.g., "Room 202"
$ShareName   = "<Share Name>"         # e.g., "HPLJM401"
# ---------------------

Write-Host "--- Adding Printer Port on $TargetPC ---" -ForegroundColor Cyan
Add-PrinterPort -ComputerName $TargetPC -Name $PortName -PrinterHostAddress $IPAddress

Write-Host "--- Adding Printer on $TargetPC ---" -ForegroundColor Cyan
Add-Printer `
    -ComputerName $TargetPC `
    -AsJob `
    -Name $PrinterName `
    -DriverName $DriverName `
    -Port $PortName `
    -Comment $Comment `
    -Location $Location `
    -Shared `
    -ShareName $ShareName

Write-Host "Printer '$PrinterName' added to $TargetPC." -ForegroundColor Green
