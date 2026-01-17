Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All | Select-Object DisplayName, UserPrincipalName, MailNickname | 
    Export-Csv -Path '.\BulkImportTemplate.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
