<#
=============================================================================================
Name:           Export Mailbox Permission Report
Website:        https://www.governmentcontrol.net/
Version:        3.0

Author:
~~~~~~~~~~~
Ryan Adams
GitHub - https://github.com/Ryan-Adams57
Gitlab https://gitlab.com/Ryan-Adams57
PasteBin https://pastebin.com/u/Removed_Content

Highlights:
~~~~~~~~~~~
1. Uses modern authentication (MFA or certificate-based) to connect to Exchange Online.
2. Only exports explicitly assigned permissions (ignores SELF and inherited permissions).
3. Supports FullAccess, SendAs, SendOnBehalf permission filters.
4. Can filter by mailbox type (user/admin) or specific mailboxes via CSV input.
5. Exports output to CSV.
6. Scheduler-friendly; supports certificate-based authentication (CBA).
7. Automatically installs required MS Graph and EXO modules if missing.
=============================================================================================
#>

param(
    [switch]$FullAccess,
    [switch]$SendAs,
    [switch]$SendOnBehalf,
    [switch]$UserMailboxOnly,
    [switch]$AdminsOnly,
    [string]$MBNamesFile,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

# --------------------------------------------
# Connect Required Modules (MS Graph & EXO)
# --------------------------------------------
Function ConnectModules {
    # Microsoft Graph Beta module
    if (-not (Get-Module Microsoft.Graph.Beta -ListAvailable)) {
        Write-Host "Microsoft Graph Beta module not found." -ForegroundColor Yellow
        $confirm = Read-Host "Install Microsoft Graph Beta module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") { Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber }
        else { Write-Host "Graph module required. Exiting." -ForegroundColor Red; Exit }
    }

    # Exchange Online module
    if (-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
        Write-Host "Exchange Online module not found." -ForegroundColor Yellow
        $confirm = Read-Host "Install Exchange Online module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") { Install-Module ExchangeOnlineManagement -Scope CurrentUser }
        else { Write-Host "EXO module required. Exiting." -ForegroundColor Red; Exit }
    }

    # Disconnect any existing sessions
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false

    Write-Progress -Activity "Connecting to Graph and Exchange Online..."

    try {
        if ($TenantId -and $ClientId -and $CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction Stop
            $Scopes = (Get-MgContext).Scopes
            if (($Scopes -notcontains "Directory.Read.All") -and ($Scopes -notcontains "Directory.ReadWrite.All")) {
                Write-Host "Application requires Directory.Read.All permission." -ForegroundColor Yellow
                Exit
            }
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        }
        else {
            Connect-MgGraph -Scopes "Directory.Read.All" -ErrorAction Stop
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red; Exit }

    Write-Host "Modules connected successfully." -ForegroundColor Cyan
}

# --------------------------------------------
# Print CSV Output
# --------------------------------------------
Function Print_Output {
    $Result = [PSCustomObject]@{
        'DisplayName'   = $DisplayName
        'UserPrincipalName' = $UPN
        'MailboxType'   = $MBType
        'AccessType'    = $AccessType
        'UserWithAccess'= $UserWithAccess
        'Roles'         = $Roles
    }
    $Result | Export-Csv -Path $ExportCSV -Append -NoTypeInformation
}

# --------------------------------------------
# Get Mailbox Permissions
# --------------------------------------------
Function Get_MBPermission {
    if (($FilterPresent -eq 'False') -or $FullAccess) {
        $FullAccessPermissions = Get-EXOMailboxPermission -Identity $UPN -ErrorAction SilentlyContinue |
            Where { ($_.AccessRights -contains "FullAccess") -and ($_.IsInherited -eq $false) -and -not ($_.User -match "NT AUTHORITY|S-1-5-21") } |
            Select-Object -ExpandProperty User
        if ($FullAccessPermissions) {
            $AccessType = "FullAccess"
            $UserWithAccess = $FullAccessPermissions -join ','
            Print_Output
        }
    }

    if (($FilterPresent -eq 'False') -or $SendAs) {
        $SendAsPermissions = Get-EXORecipientPermission -Identity $UPN -ErrorAction SilentlyContinue |
            Where { -not ($_.Trustee -match "NT AUTHORITY|S-1-5-21") } |
            Select-Object -ExpandProperty Trustee
        if ($SendAsPermissions) {
            $AccessType = "SendAs"
            $UserWithAccess = $SendAsPermissions -join ','
            Print_Output
        }
    }

    if (($FilterPresent -eq 'False') -or $SendOnBehalf) {
        if ($SendOnBehalfPermissions) {
            $AccessType = "SendOnBehalf"
            $UserWithAccess = @()
            foreach ($DN in $SendOnBehalfPermissions) {
                $upn = (Get-EXOMailbox -Identity $DN -ErrorAction SilentlyContinue).UserPrincipalName
                if (-not $upn) { $upn = ($Users | ? { $_.MailNickname -eq $DN }).UserPrincipalName }
                $UserWithAccess += $upn
            }
            $UserWithAccess = $UserWithAccess -join ','
            Print_Output
        }
    }
}

# --------------------------------------------
# Process Each Mailbox
# --------------------------------------------
Function Get_MailBoxData {
    Write-Progress -Activity "`nProcessing mailbox: $MBUserCount`nCurrently: $DisplayName"
    $Script:MBUserCount++

    if ($UserMailboxOnly -and $MBType -ne 'UserMailbox') { return }

    # Get roles for user
    $RoleList = Get-MgBetaUserTransitiveMemberOf -UserId $UPN | Select-Object -ExpandProperty AdditionalProperties
    $RoleList = $RoleList | ? { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' }
    $Roles = if ($RoleList.Count -eq 0) { "No roles" } else { ($RoleList.displayName) -join ',' }

    if ($AdminsOnly -and $Roles -eq "No roles") { return }

    Get_MBPermission
}

# --------------------------------------------
# Disconnect Sessions
# --------------------------------------------
Function CloseConnection {
    Disconnect-MgGraph | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
}

# --------------------------------------------
# Main Execution
# --------------------------------------------
ConnectModules
Write-Host "`nNote: Run in a fresh PowerShell window if you encounter module conflicts." -ForegroundColor Yellow

$Location = Get-Location
$ExportCSV = "$Location\MBPermission_$((Get-Date -Format 'yyyy-MMM-dd-ddd hh-mm-ss tt')).csv"
$MBUserCount = 1
$Users = Get-MgBetaUser -All

# Check for access type filters
$FilterPresent = if ($FullAccess -or $SendAs -or $SendOnBehalf) { 'True' } else { 'False' }

# Get mailbox list
if ($MBNamesFile) {
    try { $MailBoxes = Import-Csv -Header "MailBoxUPN" -Path $MBNamesFile }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red; CloseConnection; Exit }

    foreach ($Mail in $MailBoxes) {
        $Mailbox = Get-EXOMailbox -Identity $Mail.MailBoxUPN -PropertySets All -ErrorAction SilentlyContinue
        if (-not $Mailbox) { Write-Host "$($Mail.MailBoxUPN) not found." -ForegroundColor Red; continue }
        $DisplayName = $Mailbox.DisplayName
        $UPN = $Mailbox.UserPrincipalName
        $MBType = $Mailbox.RecipientTypeDetails
        $SendOnBehalfPermissions = $Mailbox.GrantSendOnBehalfTo
        Get_MailBoxData
    }
}
else {
    Get-EXOMailbox -ResultSize Unlimited -PropertySets All | Where { $_.DisplayName -notlike "Discovery Search Mailbox" } | ForEach-Object {
        $DisplayName = $_.DisplayName
        $UPN = $_.UserPrincipalName
        $MBType = $_.RecipientTypeDetails
        $SendOnBehalfPermissions = $_.GrantSendOnBehalfTo
        Get_MailBoxData
    }
}

# Open CSV after execution
Write-Host "`nScript executed successfully."
if (Test-Path $ExportCSV) {
    Write-Host "Detailed report available in:" -NoNewline -ForegroundColor Yellow; Write-Host " $ExportCSV"
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
    if ($UserInput -eq 6) { Invoke-Item "$ExportCSV" }
} else {
    Write-Host "No mailbox matched the criteria." -ForegroundColor Red
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for auditing resources. ~~" -ForegroundColor Green
CloseConnection
