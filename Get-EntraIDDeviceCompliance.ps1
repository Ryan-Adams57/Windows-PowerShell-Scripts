Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' }
    Get-MgDevice -All | Select-Object DisplayName, OperatingSystem, IsCompliant, TrustType | 
    Export-Csv -Path '.\DeviceCompliance.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
