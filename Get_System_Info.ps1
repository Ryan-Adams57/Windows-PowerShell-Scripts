# Computer system
Get-CimInstance -ClassName Win32_ComputerSystem

# BIOS
Get-CimInstance -ClassName Win32_BIOS

# Motherboard
Get-CimInstance -ClassName Win32_Baseboard

# CPU
Get-CimInstance -ClassName Win32_Processor

# Logical Drives
Get-CimInstance -ClassName Win32_LogicalDisk

# Physical Drives
Get-CimInstance -ClassName Win32_DiskDrive

# Memory
Get-CimInstance -ClassName Win32_PhysicalMemory

# Network Adapters
Get-CimInstance -ClassName Win32_NetworkAdapter
Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration
