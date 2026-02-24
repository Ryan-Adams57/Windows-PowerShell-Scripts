# Install-RSATTools.ps1
# Installs Remote Server Administration Tools (RSAT) on Windows 10/11
# Must be run as Administrator
# Requires internet access to Windows Update

Write-Host "--- Installing RSAT Tools ---" -ForegroundColor Cyan

# View available RSAT features
Write-Host "`nAvailable RSAT capabilities:" -ForegroundColor Yellow
Get-WindowsCapability -Online -Name RSAT* | Select-Object Name, State | Format-Table -AutoSize

# Install all RSAT tools
Write-Host "`nInstalling all RSAT tools..." -ForegroundColor Yellow
Get-WindowsCapability -Online -Name RSAT* | Add-WindowsCapability -Online

Write-Host "RSAT installation complete." -ForegroundColor Green

# If issues occur with missing DLLs, uncomment and run the block below:
<#
Write-Host "--- Fixing DLL issues (GAC install) ---" -ForegroundColor Yellow
Add-Type -AssemblyName "System.EnterpriseServices"
$publish = [System.EnterpriseServices.Internal.Publish]::new()
$dlls = @(
    'System.Memory.dll',
    'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll',
    'System.Security.Principal.Windows.dll'
)
foreach ($dll in $dlls) {
    $dllPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\$dll"
    $publish.GacInstall($dllPath)
}
New-Item -Path "$env:SystemRoot\System32\WindowsPowerShell\v1.0\" -Name DllFix.txt -ItemType File `
    -Value "$dlls added to the Global Assembly Cache" -Force
Write-Host "DLL fix applied." -ForegroundColor Green
#>
