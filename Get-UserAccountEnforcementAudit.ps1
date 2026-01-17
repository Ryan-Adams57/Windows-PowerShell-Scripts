Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -All -Property 'DisplayName', 'AccountEnabled' | Export-Csv -Path '.\AccountStatus.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
