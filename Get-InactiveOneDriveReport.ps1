Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Reports.Read.All' }
    Get-MgReportOnedriveUsageAccountDetail -Period 'D90' -OutFile '.\InactiveOneDrive.csv'
} Catch { Write-Error $_.Exception.Message }
