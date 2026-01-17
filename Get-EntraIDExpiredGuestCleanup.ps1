Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    Get-MgUser -Filter "UserType eq 'Guest' and AccountEnabled eq false" -All | 
    Select-Object DisplayName, Mail, ID | Export-Csv -Path '.\ExpiredGuests.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
