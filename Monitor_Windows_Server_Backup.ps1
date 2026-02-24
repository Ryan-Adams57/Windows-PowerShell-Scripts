$Date = (Get-Date).AddDays(-1)
$WBS = Get-WBBackupSet -ErrorAction SilentlyContinue

foreach ($Backup in $WBS) {
    $LastBackup = $Backup.LastBackupTime
    $LastSuccessful = $Backup.LastSuccessfulBackupTime
    $Result = $Backup.LastBackupResult

    if ($Result -eq 'Succeeded') {
        $Body = "Backup successful on $($env:COMPUTERNAME)`nDate: $LastSuccessful`nVersions: $($Backup.NumberOfVersions)"
        Send-MailMessage -To "recipient@email.com" -From "sender@email.com" -Subject "Backup Successful - $($env:COMPUTERNAME)" -Body $Body -SmtpServer "YourSMTPServer"
    } else {
        $ErrorDesc = (Get-WBJob -Previous 1).ErrorDescription
        $Body = "Backup failed on $($env:COMPUTERNAME)`nDate: $LastBackup`nReason: $ErrorDesc"
        Send-MailMessage -To "recipient@email.com" -From "sender@email.com" -Subject "Backup Failed - $($env:COMPUTERNAME)" -Body $Body -SmtpServer "YourSMTPServer"
    }
}
