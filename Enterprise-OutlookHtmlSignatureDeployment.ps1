<# -----------------------------------------------------------------------------------------------------------
Name           : Enterprise Outlook HTML Signature Deployment Script
Version        : 2.0
Author         : Ryan Adams
Website        : https://www.governmentcontrol.net/
GitHub         : https://github.com/Ryan-Adams57
GitLab         : https://gitlab.com/Ryan-Adams57
PasteBin       : https://pastebin.com/u/Removed_Content

Script Highlights:
~~~~~~~~~~~~~~~~~

1. Automatically verifies and installs the Exchange Online PowerShell module (if not installed).
2. Supports HTML signature deployment using in-built or custom templates.
3. Allows deployment to all mailboxes, user-only mailboxes, or bulk users via CSV.
4. Exports signature deployment status to a CSV file.
5. Supports certificate-based authentication (CBA).

---------------------------------------------------------------------------------------------------------- #>

#Block for passing params
[CmdletBinding(DefaultParameterSetName = 'NoParams')]
param
(
  [Parameter()]
  [string]$Organization,
  [Parameter()]
  [string]$ClientId,
  [Parameter()]
  [string]$CertificateThumbprint,
  [Parameter()]
  [string]$UserPrincipalName,
  [Parameter()]
  [string]$Password,
  [Parameter(ParameterSetName = 'HTMLSignature_WithInbuiltHTML')]
  [switch]$AssignDefault_HTMLSignature,
  [Parameter(ParameterSetName = 'GetHTMLTemplateFromUser')]
  [switch]$AssignCustom_HTMLSignature,
  [Parameter()]
  [switch]$Enable_PostponeRoamingSignatureUntilLater,
  [Parameter()]
  [string]$UserListCsvPath,
  [Parameter()]
  [switch]$AllUsers,
  [Parameter()]
  [switch]$UserMailboxOnly,
  [Parameter(ParameterSetName = 'GetHTMLTemplateFromUser')]
  [string]$HTML_FilePath
)

Function Installation-Module{
    $Module = (Get-Module ExchangeOnlineManagement -ListAvailable)
    if ($Module.count -eq 0)
    {
      Write-Host "`nExchange Online PowerShell module is not available." -ForegroundColor Red
      $Confirm = Read-Host "`nInstall module now? [Y] Yes [N] No"
      if ($Confirm -match "[yY]")
      {
        Write-Host "`nInstalling Exchange Online PowerShell module..." -ForegroundColor Yellow
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
      }
      else
      {
        Write-Host "`nExchange Online module is required. Install using 'Install-Module ExchangeOnlineManagement'." -ForegroundColor Yellow
        exit
      }
    }
    Import-Module ExchangeOnlineManagement
}

Function Connection-Module
{
    Write-Host "`nConnecting to Exchange Online..."
    if ($UserPrincipalName -and $Password)
    {
      $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
      $UserCredential = New-Object System.Management.Automation.PSCredential ($UserPrincipalName,$SecurePassword)
      Connect-ExchangeOnline -Credential $UserCredential -ShowBanner:$false
    }
    elseif ($Organization -and $ClientId -and $CertificateThumbprint)
    {
      Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
    }
    else
    {
      Connect-ExchangeOnline -ShowBanner:$false
    }
}

Function Enable-PostponeRoamingSign
{
if (-not (Get-OrganizationConfig).PostponeRoamingSignaturesUntilLater)
{
  if (-not $Enable_PostponeRoamingSignatureUntilLater)
  {
    Write-Host "`nEnable 'PostponeRoamingSignatureUntilLater' to deploy signatures." -ForegroundColor Yellow
    Write-Host "`n1. Enable and continue.`n2. Continue without enabling." -ForegroundColor Cyan
    $UserConfirmation = Read-Host "`nEnter your choice"
  }
  while ($true)
  {
    if ($Enable_PostponeRoamingSignatureUntilLater -or $UserConfirmation -eq 1)
    {
        Set-OrganizationConfig -PostponeRoamingSignaturesUntilLater $true
        if($?)
        {
         Write-Host "`nPostponeRoamingSignatureUntilLater enabled.`n" -ForegroundColor Green
         break
        }
        else
        {
         Write-Host "`nFailed to enable setting: $($_.Exception.Message)" -ForegroundColor Red
         Exit
        }
    }
    elseif ($UserConfirmation -eq 2)
    {
      Write-Host "`nProceeding without enabling. Signatures will not auto-deploy.`n" -ForegroundColor Yellow
      break
    }
    else
    {
      Write-Host "`nEnter a valid choice." -ForegroundColor Red
      $UserConfirmation = Read-Host
    }
  }
}
else
{
  Write-Host "`nPostponeRoamingSignatureUntilLater already enabled.`n"
  $Script:UserConfirmation = 1
}
}

function Preview-Signature ($FilePath)
{
  $FileExtension = [System.IO.Path]::GetExtension($FilePath)
  if ($FileExtension -notin ".html",".htm")
  {
    Write-Host "`nInvalid file format. HTML required." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    exit
  }
  $Decision = $Host.UI.PromptForChoice("Confirmation","Preview HTML Signature?","&Yes","&No",1)
  if ($Decision -eq 0) { Start-Process $FilePath }
  $UserChoice = Read-Host "`nProceed with this template? [Y/N]"
  if ($UserChoice -notmatch "[yY]") { Disconnect-ExchangeOnline; exit }
}

function Get-UsersForAssignSignature
{
  if ($AllUsers) { $ImportUsersType = 1 }
  elseif ($UserListCsvPath) { $ImportUsersType = 2 }
  elseif ($UserMailboxOnly) { $ImportUsersType = 3 }
  else
  {
    Write-Host "`n1. All mailboxes`n2. Import CSV`n3. User mailboxes only" -ForegroundColor Cyan
    $ImportUsersType = Read-Host "`nEnter choice"
  }

  switch ($ImportUsersType)
  {
    1 { return Get-EXOMailbox -ResultSize Unlimited | Select-Object UserPrincipalName -Unique }
    2 {
        $Path = if ($UserListCsvPath) { $UserListCsvPath } else { Read-Host "Enter CSV path" }
        return Import-Csv $Path | Select-Object UserPrincipalName -Unique
      }
    3 { return Get-EXOMailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Select-Object UserPrincipalName -Unique }
    default { Write-Host "Invalid input."; exit }
  }
}

function Get-HTMLContent
{
  $Path = if ($HTML_FilePath) { $HTML_FilePath } else { Read-Host "Enter HTML file path" }
  $HTMLcontent = Get-Content -Path $Path -Raw
  Preview-Signature $Path
  return [string]$HTMLcontent
}

function Generate-UserAddress ($UserDetails)
{
  $Address = ""
  if ($UserDetails.StreetAddress) { $Address += $UserDetails.StreetAddress + ", " }
  if ($UserDetails.City) { $Address += $UserDetails.City + ", " }
  if ($UserDetails.StateOrProvince) { $Address += $UserDetails.StateOrProvince + ",<br>" }
  if ($UserDetails.PostalCode) { $Address += $UserDetails.PostalCode + ", " }
  if ($UserDetails.CountryOrRegion) { $Address += $UserDetails.CountryOrRegion + "." }
  return $Address
}

function Deploy-InbuiltHTMLSignature
{
  $Filepath = Join-Path $PSScriptRoot "Build-InTemplate.html"
  $DefaultHTML = Get-Content $Filepath -Raw
  Preview-Signature $Filepath
  $UsersCollection = Get-UsersForAssignSignature
  $SignatureLog_FilePath = "$(Get-Location)\SignatureDeployment_$(Get-Date -Format yyyy-MM-dd_HH-mm-ss).csv"

  foreach ($User in $UsersCollection)
  {
    try
    {
      $UserDetails = Get-User -Identity $User.UserPrincipalName
      $Address = Generate-UserAddress $UserDetails
      $UserHTMLSignature = $DefaultHTML -replace "%%DisplayName%%",$UserDetails.DisplayName `
        -replace "%%Title%%",$UserDetails.Title `
        -replace "%%Email%%",$UserDetails.UserPrincipalName `
        -replace "%%MobilePhone%%",$UserDetails.MobilePhone `
        -replace "%%BusinessPhone%%",$UserDetails.Phone `
        -replace "%%CompanyName%%",$UserDetails.Office `
        -replace "%%Address%%",$Address

      Set-MailboxMessageConfiguration -Identity $UserDetails.UserPrincipalName `
        -SignatureHTML $UserHTMLSignature `
        -AutoAddSignature $true `
        -AutoAddSignatureOnMobile $true `
        -AutoAddSignatureOnReply $true

      $DeploymentStatus = "Successful"
    }
    catch
    {
      $DeploymentStatus = "Failed"
      $ErrorMessage = $_.Exception.Message
    }

    [pscustomobject]@{
      UserPrincipalName = $User.UserPrincipalName
      DeploymentStatus  = $DeploymentStatus
      Error             = if ($ErrorMessage) { $ErrorMessage } else { "-" }
    } | Export-Csv -Path $SignatureLog_FilePath -NoTypeInformation -Append
  }

  Disconnect_ExchangeOnline_Safely
}

function Deploy-CustomHTMLSignature
{
  $HTMLSignature = Get-HTMLContent
  $UsersCollection = Get-UsersForAssignSignature
  $SignatureLog_FilePath = "$(Get-Location)\SignatureDeployment_$(Get-Date -Format yyyy-MM-dd_HH-mm-ss).csv"

  foreach ($User in $UsersCollection)
  {
    try
    {
      $UserDetails = Get-User -Identity $User.UserPrincipalName
      $Address = Generate-UserAddress $UserDetails
      $UserSignature = $HTMLSignature.Replace('%%DisplayName%%',$UserDetails.DisplayName).
        Replace('%%EmailAddress%%',$UserDetails.UserPrincipalName).
        Replace('%%MobilePhone%%',$UserDetails.MobilePhone).
        Replace('%%BussinessPhone%%',$UserDetails.Phone).
        Replace('%%Department%%',$UserDetails.Department).
        Replace('%%Title%%',$UserDetails.Title).
        Replace('%%Office%%',$UserDetails.Office).
        Replace('%%Address%%',$Address)

      Set-MailboxMessageConfiguration -Identity $UserDetails.UserPrincipalName `
        -SignatureHTML $UserSignature `
        -AutoAddSignature $true `
        -AutoAddSignatureOnMobile $true `
        -AutoAddSignatureOnReply $true

      $DeploymentStatus = "Successful"
    }
    catch
    {
      $DeploymentStatus = "Failed"
      $ErrorMessage = $_.Exception.Message
    }

    [pscustomobject]@{
      UserPrincipalName = $User.UserPrincipalName
      DeploymentStatus  = $DeploymentStatus
      Error             = if ($ErrorMessage) { $ErrorMessage } else { "-" }
    } | Export-Csv -Path $SignatureLog_FilePath -NoTypeInformation -Append
  }

  Disconnect_ExchangeOnline_Safely
}

function Disconnect_ExchangeOnline_Safely
{
  Disconnect-ExchangeOnline -Confirm:$false
  Write-Host "`nSignature deployment complete."
  Write-Host "For more resources visit https://www.governmentcontrol.net/"
  exit
}

Installation-Module
Connection-Module
Enable-PostponeRoamingSign

if (-not ($AssignDefault_HTMLSignature -or $AssignCustom_HTMLSignature))
{
  Write-Host "`n1. Use in-built HTML template`n2. Use custom HTML template" -ForegroundColor Cyan
  $UserChoice = Read-Host "`nEnter choice"
}

while ($true)
{
  if ($AssignDefault_HTMLSignature -or $UserChoice -eq 1)
  {
    Deploy-InbuiltHTMLSignature
  }
  elseif ($AssignCustom_HTMLSignature -or $UserChoice -eq 2)
  {
    Deploy-CustomHTMLSignature
  }
  else
  {
    Write-Host "Invalid choice."
    $UserChoice = Read-Host
  }
}
