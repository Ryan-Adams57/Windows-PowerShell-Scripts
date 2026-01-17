Try {
    $Sites = Get-SPOSite -Limit All
    foreach ($Site in $Sites) { Get-SPOWeb -Site $Site.Url | Select-Object Title, Url } | 
    Export-Csv -Path '.\SPOSubsites.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
