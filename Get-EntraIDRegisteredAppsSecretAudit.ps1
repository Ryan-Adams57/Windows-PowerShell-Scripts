Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes 'Application.Read.All' }
    Get-MgApplication -All | ForEach-Object { 
        $App = $_; $App.PasswordCredentials | Select-Object @{N='AppName';E={$App.DisplayName}}, DisplayName, StartDateTime, EndDateTime 
    } | Export-Csv -Path '.\AppSecretsAudit.csv' -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
