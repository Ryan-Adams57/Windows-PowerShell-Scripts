Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'AuditLog.Read.All' }
    $Date = (Get-Date).AddDays(-7)
    $Logs = Get-MgAuditLogDirectoryAudit -Filter "category eq 'GroupManagement' and activityDateTime ge $($Date.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    $Logs | Where-Object { $_.ActivityDisplayName -match 'member' } | Select-Object ActivityDateTime, ActivityDisplayName, @{N='Group';E={$_.TargetResources[0].DisplayName}} | 
    Export-Csv -Path '.\GroupMembershipChanges.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
