Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' }
    $Cutoff = (Get-Date).AddDays(-180)
    Get-MgUser -Filter "UserType eq 'Guest'" -All -Property 'DisplayName', 'Mail', 'SignInActivity' | 
    Where-Object { $_.SignInActivity.LastSignInDateTime -lt $Cutoff } | 
    Export-Csv -Path '.\StaleGuests.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
