# Set-NetworkIPConfig.ps1
# Configure a network interface for DHCP or a static IP address
# Must be run as Administrator

Write-Host "=== Network IP Configuration ===" -ForegroundColor Cyan
Write-Host "Available Network Interfaces:" -ForegroundColor Yellow
Get-NetIPInterface | Select-Object ifIndex, InterfaceAlias, AddressFamily, Dhcp | Format-Table -AutoSize

# --- Set to DHCP ---
# Replace <#> with the ifIndex from the list above
# $ifIndex = <#>
# Set-NetIPInterface -ifIndex $ifIndex -Dhcp Enabled
# Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses
# Write-Host "Interface $ifIndex set to DHCP." -ForegroundColor Green

# --- Set Static IP ---
# Replace values as needed
# $ifIndex    = <#>
# $IPAddress  = "<IP>"          # e.g., "192.168.1.50"
# $PrefixLen  = <#>             # e.g., 24 (for /24 subnet)
# $Gateway    = "<GWIP>"        # e.g., "192.168.1.1"
# $DNS1       = "<DNS1>"        # e.g., "8.8.8.8"
# $DNS2       = "<DNS2>"        # e.g., "8.8.4.4"
#
# New-NetIPAddress -IPAddress $IPAddress -PrefixLength $PrefixLen -DefaultGateway $Gateway -InterfaceIndex $ifIndex
# Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses ($DNS1, $DNS2)
# Write-Host "Static IP $IPAddress set on interface $ifIndex." -ForegroundColor Green
