# Enable-BitLockerAES256.ps1
# Enables BitLocker on C: drive with TPM + Recovery Password protectors
# Must be run as Administrator
# Also backs up recovery key to AD if configured

Write-Host "--- Enabling BitLocker on C: with AES256 ---" -ForegroundColor Cyan

# Add Recovery Password Protector (stores key in AD if configured)
Add-BitLockerKeyProtector -MountPoint C: -RecoveryPasswordProtector | Out-Null

# Enable BitLocker with TPM and AES256
Enable-BitLocker -MountPoint C: -TpmProtector -EncryptionMethod AES256 -SkipHardwareTest

Write-Host "BitLocker enabled. Use 'manage-bde -status C:' to check encryption progress." -ForegroundColor Green
