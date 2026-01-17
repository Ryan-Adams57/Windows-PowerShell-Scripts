<#
Name:           Password Never Expires Report
Description:    Identifies cloud users set to 'PasswordNeverExpires'.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.Read.All" }
    $Users = Get-MgUser -All -Property "DisplayName", "UserPrincipalName", "PasswordPolicies"
    $Results = $Users | Where-Object { $_.PasswordPolicies -match "DisablePasswordExpiration" }
    $Results | Select-Object DisplayName, UserPrincipalName, PasswordPolicies | Export-Csv -Path ".\PasswordNeverExpires.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
