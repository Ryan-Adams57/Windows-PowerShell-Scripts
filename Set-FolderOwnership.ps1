# Set-FolderOwnership.ps1
# Takes ownership of a folder and sets permissions recursively
# Must be run as Administrator

# --- Configuration ---
$FolderPath  = "<Path\ToFolder>"      # e.g., "C:\Data\SharedFolder"
$OwnerUser   = "<Domain\User>"        # e.g., "CONTOSO\jsmith"
$GrantUser   = "<Domain\UserOrGroup>" # e.g., "CONTOSO\IT_Admins"
$Rights      = "F"                    # F=Full, M=Modify, RX=Read&Execute, R=Read, W=Write
# ---------------------

Write-Host "--- Taking Ownership of $FolderPath ---" -ForegroundColor Cyan

# Take ownership and assign to Administrators group (recursive, /D N = default No for prompts)
takeown /R /A /F "$FolderPath" /D N

# Set owner to specific domain user (recursive, /T = recurse, /C = continue on error)
icacls /setowner "$OwnerUser" /T /C "$FolderPath"

# Grant rights to user or group
icacls "$FolderPath" /grant "${GrantUser}:(${Rights})" /T /C

Write-Host "Ownership and permissions set." -ForegroundColor Green
