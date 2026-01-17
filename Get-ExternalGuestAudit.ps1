<#
Name:           Entra ID Guest User Audit
Description:    Lists all guest users and their invitation status.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.Read.All" }
    $Guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property "DisplayName", "Mail", "ExternalUserState", "CreationDateTime"
    $Guests | Export-Csv -Path ".\GuestAudit.csv" -NoTypeInformation
    Write-Host "Guest user audit exported." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
