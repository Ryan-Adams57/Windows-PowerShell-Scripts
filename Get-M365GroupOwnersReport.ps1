<#
Name:           M365 Group Owners Audit
Description:    Lists all Unified Groups and their designated owners.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Group.Read.All" }
    $Groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All
    $Results = foreach ($G in $Groups) {
        $Owners = Get-MgGroupOwner -GroupId $G.Id
        [PSCustomObject]@{
            GroupName = $G.DisplayName
            Owners    = ($Owners.AdditionalProperties.userPrincipalName -join "; ")
        }
    }
    $Results | Export-Csv -Path ".\GroupOwners.csv" -NoTypeInformation
    Write-Host "Group Owners report generated." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
