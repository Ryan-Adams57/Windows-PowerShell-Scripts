Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'User.Read.All' }
    foreach ($U in (Get-MgUser -All)) { 
        $HasPhoto = $true; Try { Get-MgUserPhoto -UserId $U.Id -ErrorAction Stop } Catch { $HasPhoto = $false }
        [PSCustomObject]@{ UPN = $U.UserPrincipalName; HasPhoto = $HasPhoto } 
    } | Export-Csv -Path '.\ProfilePhotos.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
