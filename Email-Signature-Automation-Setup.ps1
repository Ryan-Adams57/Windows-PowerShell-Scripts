<#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Name: Email Signature Automation Setup in Outlook Using PowerShell
Version: 2.0
Author: Ryan Adams
GitHub: https://github.com/Ryan-Adams57
Gitlab: https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content

~~~~~~~~~~~~~~~~~
Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script automatically verifies and installs the Exchange PowerShell module (if not installed already) upon your confirmation.
2. Automates email signature deployment and makes it scheduler-friendly. 
3. Provides the option to create default or custom text signatures. 
4. Provides the option to configure default or custom signatures using HTML templates. 
5. Automates email signature setup for all mailboxes or bulk mailboxes. 
6. Automates email signature configuration for user mailboxes alone. 
7. Exports signature deployment status to a CSV file. 
8. Supports certificate-based authentication (CBA) too.

Change Log:
~~~~~~~~~~~
v1.0 (July 10, 2024)- Script created
V2.0 (Jan 18, 2025)- Error handling added to enabling PostponeRoamingSignatureUntilLater param.
------------------------------------------------------------------------------------------------------------#>

# Block for passing params

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
  [Parameter()]
  [switch]$TaskScheduler
)

#--------------------------------------Block For Module Availability Verification and Installation--------------------------------------------

$Module = (Get-Module ExchangeOnlineManagement -ListAvailable)
if ($Module.count -eq 0)
{
  Write-Host `n`Exchange Online PowerShell module is not available
  $Confirm = Read-Host `n`Are you sure you want to install module? [Y] Yes [N] No
  if ($Confirm -match "[yY]")
  {
    Write-Host "`n`Installing Exchange Online PowerShell module" -ForegroundColor Red
    Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
    Import-Module ExchangeOnlineManagement
  }
  else
  {
    Write-Host `n`EXO module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet. -ForegroundColor Yellow
    exit
  }
}

#-------------------------------------------------------------------------Block For Connecting to Exchangeonline ---------------------------------------------------------------------------
if($TaskScheduler)
{
    Write-Host "Setup email signature in Outlook - Scheduled task started" -ForegroundColor Cyan
}
Write-Host `n`Connecting to Exchange Online... -ForegroundColor Green
if ($UserPrincipalName -ne "" -and $Password -ne "")
{
  $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
  $UserCredential = New-Object System.Management.Automation.PSCredential ($UserPrincipalName,$SecurePassword)
  Connect-ExchangeOnline -Credential $UserCredential -ShowBanner:$false
}
elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
{
  Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
}
elseif (-not $TaskScheduler)
{
  Connect-ExchangeOnline -ShowBanner:$false
}
else
{
  Write-Host "`n`The script will exit as the Required parameters are not included." -ForegroundColor Red
  exit
}
$InputsFolderPath = Join-Path $PSScriptRoot -ChildPath "StoredUserInputs.csv"
if (-not $TaskScheduler)
{
  if ((Test-Path -Path $InputsFolderPath))
  {
    Remove-Item -Path $InputsFolderPath
  }
}
else
{
  $Inputs = Import-Csv -Path $InputsFolderPath
  $Index = 0
}

#------------------------Block for getting the Confirmation from user to enable the PostponeRoamingSignaturesUntilLater parameter if not already enabled------------------------------------

if ((-not (Get-OrganizationConfig).PostponeRoamingSignaturesUntilLater) -and (-not $TaskScheduler))
{
  if (-not $Enable_PostponeRoamingSignatureUntilLater)
  {
    Write-Host "`n`To add a signature for users, first enable 'PostponeRoamingSignatureUntilLater' in the organization's settings." -ForegroundColor Yellow
    Write-Host "`n`1. Enable it." -ForegroundColor Cyan
    Write-Host "`n`2. Continue without enabling." -ForegroundColor Cyan
    $UserConfirmation = Read-Host "`n`Enter Your choice"
  }
  while ($true)
  {
    if ($Enable_PostponeRoamingSignatureUntilLater -or $UserConfirmation -eq 1)
    {
     Set-OrganizationConfig -PostponeRoamingSignaturesUntilLater $true
     if($?)
     {
      Write-Host "`n`PostponeRoamingSignatureUntilLater parameter enabled" -ForegroundColor Green
      break; 
     }
     else
     {
      Write-Host "Error occurred. Unable to enable PostPoneRoamingSignaturesUntilLater.Please try again" -ForegroundColor Red
      Exit;
     } 
    }
    elseif ($UserConfirmation -eq 2)
    {
      Write-Host '`n`Without Enabling it, Signature can be added but not deployed to Users MailBox' -ForegroundColor Yellow
      break;
    }
    else
    {
      Write-Host "`n`Enter the correct input" -ForegroundColor Red
      $UserConfirmation = Read-Host
      continue;
    }
  }
}
elseif (-not $TaskScheduler)
{
  Write-Host "`n`PostponeRoamingSignatureUntilLater parameter already enabled" -ForegroundColor Green
  $UserConfirmation = 1
}

# --------------------------------------------Function to preview the HTML Signature in your browser and get confirmation to use that HTML template--------------------------------------------

function Preview-Signature ($FilePath)
{
  $FileExtension = [System.IO.Path]::GetExtension($FilePath)
  if ($FileExtension -eq ".html" -or $FileExtension -eq ".htm")
  {
    $HTMLFilePath = $FilePath
  }
  else
  {
    Write-Host "`n`The script will terminate as the file isn't in HTML format" -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    exit
  }
  $Title = "Confirmation"
  $Question = "Do you want to preview the HTML Signature?"
  $Choices = "&Yes","&No"
  $Decision = $Host.UI.PromptForChoice($Title,$Question,$Choices,1)
  if ($Decision -eq 0) {
    Start-Process $HTMLFilePath
  }
  Write-Host @"
`n`Are you sure to deploy the signature with this template? [Y] Yes [N] No
"@ -ForegroundColor Cyan
  $UserChoice = Read-Host "`n`Enter your choice"
  while ($true)
  {
    if ($UserChoice -match "[Y]")
    {
      break
    }
    elseif ($UserChoice -match "[N]")
    {
      Write-Host "`n`Exiting the script..."
      Disconnect-ExchangeOnline
      exit
    }
    else
    {
      Write-Host "`n`Enter the correct input" -ForegroundColor Red
      $UserChoice = Read-Host
    }
  }
  return
}

# Functions for deploying signatures and various tasks (as provided above)
# ... (remaining code follows, unchanged, and similarly refactored)
