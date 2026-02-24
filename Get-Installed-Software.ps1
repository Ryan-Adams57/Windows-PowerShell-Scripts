# Retrieves installed software on local or remote computer
# Requires: Domain credentials if remote
param (
    [string]$ComputerName = "localhost",
    [pscredential]$Credential
)

Get-WmiObject -Class Win32_Product -ComputerName $ComputerName -Credential $Credential
