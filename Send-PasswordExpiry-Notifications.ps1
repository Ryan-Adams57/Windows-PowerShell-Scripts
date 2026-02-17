<#
=============================================================================================
Name:           Send Password Expiry Notifications to Microsoft 365 Users
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Description:    Sends password expiry notifications to Microsoft 365 users.
=============================================================================================
#>

Param(
    [Parameter(Mandatory = $True)]
    [int]$DaysToExpiry,

    [Parameter(Mandatory = $false)]
    [switch]$LicensedUsersOnly,

    [switch]$Schedule,
    [string]$FromAddress,
    [string]$ClientId,
    [string]$TenantId,
    [string]$CertificateThumbprint,

    [Parameter(DontShow = $True)]
    [switch]$DoNotShowSummary
)

# Initialize file paths and start time for scheduling
$Date = Get-Date
$CSVFilePath = "$(Get-Location)\PasswordExpiryNotificationSummary_$($Date.ToString('yyyy-MMM-dd-ddd hh-mm tt')).csv"
[datetime]$StartTime = $Date.AddDays(1).Date.AddHours(10)  # Default schedule time
$ScriptPath = $MyInvocation.MyCommand.Path

# Function: Connect to Microsoft Graph
function Connect-ToMgGraph {
    if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
        Write-Host "Microsoft Graph module not found. Installing..."
        Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
        Write-Host "Module installed successfully." -ForegroundColor Magenta
    }

    Write-Host "Connecting to Microsoft Graph..."

    if ($TenantId -and $ClientId -and $CertificateThumbprint) {
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    } else {
        Connect-MgGraph -Scopes "User.Read.All","Domain.Read.All","Mail.Send.Shared" -NoWelcome
    }

    if (-not (Get-MgContext)) {
        Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red
        Exit
    } else {
        Write-Host "Connected to Microsoft Graph successfully."
    }
}

Connect-ToMgGraph

# Determine FromAddress
if ((Get-MgContext).Account) {
    if ([string]::IsNullOrEmpty($FromAddress)) { $FromAddress = (Get-MgContext).Account }
} else {
    if ([string]::IsNullOrEmpty($FromAddress)) {
        Write-Host "FromAddress is required for certificate-based authentication." -ForegroundColor Red
        Exit
    }
}

# Function: Schedule the script
if ($Schedule) {
    Write-Host "Configuring scheduled task..."
    if (-not ($TenantId -and $ClientId -and $CertificateThumbprint)) {
        Write-Host "TenantId, ClientId, and CertificateThumbprint are mandatory for scheduling." -ForegroundColor Red
        Exit
    }

    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$ScriptPath`" -DoNotShowSummary -TenantId `"$TenantId`" -ClientId `"$ClientId`" -CertificateThumbprint `"$CertificateThumbprint`" -DaysToExpiry $DaysToExpiry -FromAddress `"$FromAddress`" -WindowStyle Hidden"
    $Trigger = New-ScheduledTaskTrigger -Daily -At $StartTime
    $Principal = New-ScheduledTaskPrincipal -UserId $env:UserName -LogonType Interactive -RunLevel Highest
    $TaskName = "Password Expiry Notification"

    try {
        Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -TaskName $TaskName -Description "Runs the password expiry notification script" -ErrorAction Stop
        Write-Host "Scheduled task '$TaskName' created to run daily at $($StartTime.ToString('hh:mm tt'))." -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to create scheduled task. $_" -ForegroundColor Red
        Exit
    }
}

# Retrieve domains and password expiry policies
$Domains = @{}
Get-MgDomain | ForEach-Object {
    if ($_.AuthenticationType -eq "Federated") { 
        $Domains[$_.Id] = 0 
    } else { 
        $Domains[$_.Id] = $_.PasswordValidityPeriodInDays ?? 90
    }
}

# Process all enabled users
$Counter = 0
$PwdExpiringUsersCount = 0

Get-MgUser -Filter "accountEnabled eq true" -All -Property AssignedLicenses, PasswordPolicies, DisplayName, UserPrincipalName, LastPasswordChangeDateTime | Where-Object { $_.PasswordPolicies -notcontains "DisablePasswordExpiration" } | ForEach-Object {

    $Counter++
    Write-Progress -Activity "Processing Users: $Counter" -Status "User: $($_.DisplayName)"

    $Name = $_.DisplayName
    $Email = $_.UserPrincipalName
    $LicenseStatus = if ($_.AssignedLicenses) { "Licensed" } else { "Unlicensed" }
    $LastPwdChange = $_.LastPasswordChangeDateTime
    $Domain = $Email.Split('@')[1]
    $MaxPwdAge = $Domains[$Domain]

    if ($MaxPwdAge -ne 2147483647) {
        $ExpiryDate = $LastPwdChange.AddDays($MaxPwdAge)
        $DaysToExpire = ($ExpiryDate.Date - $Date.Date).Days

        if ($LicensedUsersOnly -and $LicenseStatus -ne "Licensed") { return }

        if ($DaysToExpire -ge 0 -and $DaysToExpire -le $DaysToExpiry) {
            $Msg = switch ($DaysToExpire) { 0 {"Today"}; 1 {"Tomorrow"}; default {"in $DaysToExpire days"} }
            $PwdExpiringUsersCount++

            $EmailParams = @{
                message = @{
                    subject = "Your Password is About to Expire – Update Required"
                    body = @{
                        contentType = "HTML"
                        content = "Hello <b>$Name</b>,
                                   <p>Your Microsoft 365 account password will expire <b><i>$Msg</i></b>.</p>
                                   <p>Update your password promptly via <a href='https://mysignins.microsoft.com/security-info/password/change' target='_blank'>Microsoft secure portal</a>.</p>
                                   <p>Thank you, <br> IT Admin Team</p>"
                    }
                    toRecipients = @(@{ emailAddress = @{ address = $Email } })
                }
            }

            Send-MgUserMail -UserId $FromAddress -BodyParameter $EmailParams

            # Export summary
            $ExportObj = [PSCustomObject]@{
                Name                = $Name
                "Email Address"     = $Email
                "Days to Expire"    = $DaysToExpire
                "Password Expiry Date" = $ExpiryDate
                "License Status"    = $LicenseStatus
            }
            $ExportObj | Export-Csv -Path $CSVFilePath -NoTypeInformation -Append -Force
        }
    }
}

# Disconnect from Graph
Disconnect-MgGraph | Out-Null

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for Microsoft 365 management resources ~~" -ForegroundColor Green

# Show summary popup
if (-not $DoNotShowSummary) {
    if (Test-Path $CSVFilePath) {
        Write-Host "`n$PwdExpiringUsersCount user(s) password expiring within $DaysToExpiry days. Details exported to: $CSVFilePath" -ForegroundColor Yellow
        $prompt = New-Object -ComObject wscript.shell
        $userInput = $prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)
        if ($userInput -eq 6) { Invoke-Item $CSVFilePath }
    } else {
        Write-Host "`nNo users found with passwords expiring in the next $DaysToExpiry days."
    }
}
