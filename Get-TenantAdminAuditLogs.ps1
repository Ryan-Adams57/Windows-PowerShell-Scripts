Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'AuditLog.Read.All' }
    $Date = (Get-Date).AddHours(-24)
    Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $($Date.ToString('yyyy-MM-ddTHH:mm:ssZ'))" | 
    Export-Csv -Path '.\AdminAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
