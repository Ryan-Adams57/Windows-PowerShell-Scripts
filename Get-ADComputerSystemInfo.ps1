# Get-ADComputerSystemInfo.ps1
# Pulls systeminfo from all AD computers and displays in a grid
# Requires AD rights and PowerShell remoting enabled on targets

(Get-ADComputer -Filter *).Name | ForEach-Object {
    Invoke-Command -ComputerName $_ {
        systeminfo /FO CSV
    } -ErrorAction SilentlyContinue | Select-Object -Skip 1
} | ConvertFrom-Csv -Header `
    "Host Name","OS","Version","Manufacturer","Configuration","Build Type",`
    "Registered Owner","Registered Organization","Product ID","Install Date",`
    "Boot Time","System Manufacturer","Model","Type","Processor","Bios",`
    "Windows Directory","System Directory","Boot Device","Language","Keyboard",`
    "Time Zone","Total Physical Memory","Available Physical Memory","Virtual Memory",`
    "Virtual Memory Available","Virtual Memory in Use","Page File","Domain",`
    "Logon Server","Hotfix","Network Card","Hyper-V" |
Out-GridView -Title "AD Computer System Information"

# To export to CSV after viewing in grid, use:
# | Out-GridView -PassThru | Export-Csv -Path 'C:\Temp\ADComputerInfo.csv' -NoTypeInformation
