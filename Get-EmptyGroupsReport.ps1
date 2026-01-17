<#
Name:           Empty Groups Audit
Description:    Identifies security and M365 groups with zero members for cleanup.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Group.Read.All" }
    Write-Host "Analyzing groups for zero membership..." -ForegroundColor Cyan
    $Groups = Get-MgGroup -All
    $Results = foreach ($G in $Groups) {
        $Count = (Get-MgGroupMember -GroupId $G.Id -Top 1).Count
        if ($Count -eq 0) {
            [PSCustomObject]@{
                GroupName = $G.DisplayName
                GroupId   = $G.Id
                GroupType = ($G.GroupTypes -join ", ")
            }
        }
    }
    $Results | Export-Csv -Path ".\EmptyGroups.csv" -NoTypeInformation
    Write-Host "Empty groups report generated." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
