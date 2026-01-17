Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Device.Read.All' }
    Get-MgDevice -All | Group-Object TrustType | Select-Object Name, Count | 
    Export-Csv -Path '.\DeviceTrustSummary.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
