<#
Name:           Licensed Users Report
Description:    Exports users and their specific license SKUs.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.Read.All", "Organization.Read.All" }
    $Skus = Get-MgSubscribedSku | Select-Object SkuId, SkuPartNumber
    $Users = Get-MgUser -All -Property "DisplayName", "UserPrincipalName", "AssignedLicenses"
    $Results = foreach ($User in $Users) {
        if ($User.AssignedLicenses) {
            $Friendly = foreach ($Lic in $User.AssignedLicenses) { ($Skus | Where-Object { $_.SkuId -eq $Lic.SkuId }).SkuPartNumber }
            [PSCustomObject]@{ User = $User.UserPrincipalName; Licenses = ($Friendly -join "; ") }
        }
    }
    $Results | Export-Csv -Path ".\UserLicenses.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
