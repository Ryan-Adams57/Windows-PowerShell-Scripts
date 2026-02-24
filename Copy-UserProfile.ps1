# Copy-UserProfile.ps1
# Copies a user profile to a new location using xcopy or robocopy
# Run as Administrator; reboot first and login as admin (not the user being copied)

# --- Configuration ---
$UserID      = "<userid>"                     # e.g., "jsmith"
$Destination = "New:\Location\Users\$UserID"  # e.g., "D:\Profiles\jsmith"
# ---------------------

Write-Host "--- Copying Profile for $UserID ---" -ForegroundColor Cyan
Write-Host "Source: C:\Users\$UserID" -ForegroundColor Yellow
Write-Host "Destination: $Destination" -ForegroundColor Yellow

# Option 1: xcopy
# /e = All subdirs (including empty), /h = Hidden, /k = Keep attribs, /r = Overwrite readonly, /c = Continue on error, /y = Silent yes
# xcopy "C:\Users\$UserID\*.*" "$Destination\" /e /h /k /r /c /y

# Option 2: robocopy (recommended)
# /b = Backup mode, /MIR = Mirror, /SEC = Copy security, /XJ = Exclude junctions, /r:0 = No retry, /w:0 = No wait
robocopy "C:\Users\$UserID\" "$Destination" /b /MIR /SEC /XJ /r:0 /w:0

Write-Host "`nCopy complete." -ForegroundColor Green
Write-Host "After successful copy on the new device:" -ForegroundColor Yellow
Write-Host "1. Log in as Admin first." -ForegroundColor Yellow
Write-Host "2. Use Profile Copy Wizard to attach the profile to the existing account (usually AD)." -ForegroundColor Yellow
Write-Host "3. Reboot, then have the user test their login and verify profile is correct." -ForegroundColor Yellow
