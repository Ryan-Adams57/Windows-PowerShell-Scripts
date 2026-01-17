<#
Name:           New-M365UserOnboarding
Description:    Creates a new Entra ID user, sets password, and assigns licenses.
Version:        1.0
#>
param(
    [Parameter(Mandatory=$true)] [string]$UserPrincipalName,
    [Parameter(Mandatory=$true)] [string]$DisplayName,
    [string]$JobTitle = "Employee",
    [string]$UsageLocation = "US",
    [string]$SkuPartNumber = "SPE_E5"
)

Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" }
    $PasswordProfile = @{ Password = "Init$(Get-Random -Minimum 1000 -Maximum 9999)!"; ForceChangePasswordNextSignIn = $true }
    
    Write-Host "Creating user $DisplayName..." -ForegroundColor Cyan
    $NewUser = New-MgUser -DisplayName $DisplayName `
                          -UserPrincipalName $UserPrincipalName `
                          -MailNickname ($UserPrincipalName.Split('@')[0]) `
                          -UsageLocation $UsageLocation `
                          -JobTitle $JobTitle `
                          -AccountEnabled $true `
                          -PasswordProfile $PasswordProfile

    $SkuId = (Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber }).SkuId
    if ($SkuId) {
        Set-MgUserLicense -UserId $NewUser.Id -AddLicenses @{ SkuId = $SkuId } -RemoveLicenses @()
        Write-Host "User created and licensed successfully." -ForegroundColor Green
    }
} Catch { Write-Error $_.Exception.Message }
