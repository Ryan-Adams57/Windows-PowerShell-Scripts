Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'AuditLog.Read.All' }
    Get-MgAuditLogDirectoryAudit -Filter "activityDisplayName eq 'Update user'" | 
    Where-Object { $_.TargetResources.ModifiedProperties.Name -contains 'Manager' } | 
    Export-Csv -Path '.\ManagerChanges.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
