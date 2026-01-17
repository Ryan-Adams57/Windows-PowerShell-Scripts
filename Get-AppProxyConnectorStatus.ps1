Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Directory.Read.All' }
    Get-MgDirectoryOnPremisesPublishingConnector | Select-Object MachineName, Status | 
    Export-Csv -Path '.\AppProxyStatus.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
