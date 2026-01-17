<#
Name:           App Registration Secret Expiry
Description:    Reports on client secrets and certificates expiring within Entra ID Apps.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Application.Read.All" }
    $Apps = Get-MgApplication -All
    $Results = foreach ($App in $Apps) {
        foreach ($Key in $App.PasswordCredentials) {
            [PSCustomObject]@{ AppName = $App.DisplayName; Type = "Secret"; Expiry = $Key.EndDateTime }
        }
    }
    $Results | Export-Csv -Path ".\AppSecretExpiry.csv" -NoTypeInformation
} Catch { Write-Error $_.Exception.Message }
