Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Group.Read.All' }
    $Groups = Get-MgGroup -All
    foreach ($G in $Groups) {
        Get-MgGroupMember -GroupId $G.Id -All | Where-Object { $_.AdditionalProperties."@odata.type" -eq "#microsoft.graph.group" } |
        Select-Object @{N='ParentGroup';E={$G.DisplayName}}, @{N='NestedGroupID';E={$_.Id}}
    } | Export-Csv -Path '.\GroupNesting.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
