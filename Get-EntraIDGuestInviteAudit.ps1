Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'AuditLog.Read.All' }
    Get-MgAuditLogDirectoryAudit -Filter "activityDisplayName eq 'Invite external user'" | 
    Select-Object ActivityDateTime, @{N='Inviter';E={$_.InitiatedBy.User.UserPrincipalName}} | 
    Export-Csv -Path '.\GuestInviteAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
