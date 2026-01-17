<#
Name:           Inactive Teams Audit
Description:    Reports on Teams with no conversation or file activity in 90 days.
Version:        1.0
#>
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "Reports.Read.All" }
    Get-MgReportTeamActivityDetail -Period "D90" -OutFile ".\TeamsActivity.csv"
    Write-Host "Teams Activity report downloaded to CSV." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
