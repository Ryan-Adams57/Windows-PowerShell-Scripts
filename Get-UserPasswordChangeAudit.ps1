Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'DisplayName', 'UserPrincipalName', 'LastPasswordChangeDateTime' | 
    Export-Csv -Path '.\PasswordAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
