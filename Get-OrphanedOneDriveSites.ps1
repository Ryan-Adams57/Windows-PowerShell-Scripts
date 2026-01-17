Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Sites.Read.All', 'User.Read.All' }
    $AllSites = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"
    $Results = foreach ($Site in $AllSites) {
        $UserUPN = $Site.Url.Split('/')[-1].Replace('_', '.')
        Try {
            $User = Get-MgUser -UserId $UserUPN -ErrorAction Stop
            if ($User.AccountEnabled -eq $false) { [PSCustomObject]@{ SiteUrl = $Site.Url; Owner = $UserUPN; Status = 'Disabled User' } }
        } Catch { [PSCustomObject]@{ SiteUrl = $Site.Url; Owner = $UserUPN; Status = 'Deleted User' } }
    }
    $Results | Export-Csv -Path '.\OrphanedOneDriveSites.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
