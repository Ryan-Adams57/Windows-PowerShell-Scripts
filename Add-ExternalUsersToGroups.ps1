# Import Exchange Online module
Import-Module ExchangeOnlineManagement

# === CONFIGURATION ===
$adminUPN = "your_admin_account@yourdomain.com"
$csvPath = "C:\Path\To\externalUsers.csv"
$logPath = "C:\Path\To\AddUsersLog.txt"
$errorLogPath = "C:\Path\To\AddUsersErrorLog.txt"

# === Connect to Exchange Online ===
Write-Host "`nConnecting to Exchange Online as $adminUPN..." -ForegroundColor Cyan
Connect-ExchangeOnline -UserPrincipalName $adminUPN

# === Import CSV ===
Write-Host "Importing users from CSV: $csvPath" -ForegroundColor Cyan
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    $email = $user.EmailAddress.Trim()
    $group = $user.DistributionGroup.Trim()

    try {
        # Check if MailContact exists
        $contact = Get-MailContact -Filter "ExternalEmailAddress -eq '$email'" -ErrorAction SilentlyContinue

        if (-not $contact) {
            Write-Host "Creating mail contact for $email..." -ForegroundColor Yellow
            New-MailContact -Name $email.Split("@")[0] -ExternalEmailAddress $email -DisplayName $email -ErrorAction Stop
            Add-Content -Path $logPath -Value "$(Get-Date): Created mail contact for $email"
        } else {
            Write-Host "Mail contact for $email already exists." -ForegroundColor Gray
            Add-Content -Path $logPath -Value "$(Get-Date): Mail contact already exists for $email"
        }

        # Add contact to Distribution Group
        Write-Host "Adding $email to $group..." -ForegroundColor Green
        Add-DistributionGroupMember -Identity $group -Member $email -ErrorAction Stop
        Add-Content -Path $logPath -Value "$(Get-Date): Added $email to $group"
    }
    catch {
        $errorMessage = "$(Get-Date): ERROR adding $email to $group - $_"
        Write-Warning $errorMessage
        Add-Content -Path $errorLogPath -Value $errorMessage
    }
}

# === Disconnect ===
Write-Host "`nDisconnecting from Exchange Online..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "`nScript completed. Check logs at:" -ForegroundColor Green
Write-Host "  $logPath" -ForegroundColor Yellow
Write-Host "  $errorLogPath" -ForegroundColor Yellow
