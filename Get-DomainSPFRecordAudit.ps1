Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Organization.Read.All' }
    foreach ($D in (Get-MgDomain)) { 
        $SPF = (Get-MgDomainServiceConfigurationRecord -DomainId $D.Id | Where-Object { $_.Text -like '*spf1*' }).Text
        [PSCustomObject]@{ Domain = $D.Id; SPF = $SPF } 
    } | Export-Csv -Path '.\DomainSPF.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
