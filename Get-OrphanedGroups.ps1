<#
Name:           Orphaned Groups Audit
Description:    Lists M365 Groups that have no assigned owners.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Group.Read.All" }
    $Groups = Get-MgGroup -All
    $Results = foreach ($G in $Groups) {
        $Owners = Get-MgGroupOwner -GroupId $G.Id -Top 1
        if (-not $Owners) {
            [PSCustomObject]@{ GroupName = $G.DisplayName; Email = $G.Mail; Created = $G.CreatedDateTime }
        }
    }
    $Results | Export-Csv -Path ".\OrphanedGroups.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
