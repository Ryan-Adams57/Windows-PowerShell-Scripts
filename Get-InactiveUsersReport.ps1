<#
Name:           M365 Inactive User Report
Description:    Identifies users who haven't signed in within a specified timeframe.
Version:        1.0
#>
param([int]MemoryDays = 90)
Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All" }
    $Cutoff = (Get-Date).AddDays(-$MemoryDays)
    Write-Host "Fetching users inactive since $($Cutoff.ToShortDateString())..." -ForegroundColor Cyan
    $Users = Get-MgUser -All -Property "DisplayName", "UserPrincipalName", "SignInActivity", "AccountEnabled"
    $Results = $Users | Where-Object { $_.SignInActivity.LastSignInDateTime -lt $Cutoff -and $_.AccountEnabled -eq $true }
    $Results | Select-Object DisplayName, UserPrincipalName, @{N='LastSignIn';E={$_.SignInActivity.LastSignInDateTime}} | Export-Csv -Path ".\InactiveUsers.csv" -NoTypeInformation
    Write-Host "Report saved to InactiveUsers.csv" -ForegroundColor Green
} Catch { Write-Error "Error: $($_.Exception.Message)" }
