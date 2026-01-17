<#
Name:           MFA Registration Audit
Description:    Identifies which MFA methods users have registered.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All" }
    $Users = Get-MgUser -All -Property "Id", "UserPrincipalName"
    $Results = foreach ($U in $Users) {
        $Methods = Get-MgUserAuthenticationMethod -UserId $U.Id
        [PSCustomObject]@{ UPN = $U.UserPrincipalName; MethodCount = ($Methods | Measure-Object).Count }
    }
    $Results | Export-Csv -Path ".\MFAStatus.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
