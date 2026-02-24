# Full help for a command
Get-Help Get-CimInstance -Full

# Show only examples
Get-Help Get-CimInstance -Examples

# Open online docs
Get-Help Get-CimInstance -Online

# Show help in a window
Get-Help Get-CimInstance -ShowWindow

# Find commands with wildcards
Get-Command -Name Get-*

# Explore object properties and methods
$Object = Get-CimInstance -ClassName Win32_ComputerSystem
$Object | Get-Member

# Check what a shorthand alias means
Get-Alias -Name gcim  # gcim = Get-CimInstance
