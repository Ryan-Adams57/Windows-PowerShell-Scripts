<#
=============================================================================================
Name:           Get Distribution Lists with External Users in Microsoft 365  
Version:        1.0
Website:        https://www.governmentcontrol.net/

Script Highlights:  
~~~~~~~~~~~~~~~~~
1. Generates a list of distribution groups with external users in Microsoft 365.  
2. Excludes external mail contacts by default, with an option to include them if required. 
3. The script automatically verifies and installs the Exchange PowerShell module (if not installed already) upon your confirmation. 
4. Exports report results to CSV. 
5. The script supports Certificate-based authentication (CBA).  
6. The script is scheduler friendly.  

For detailed Script execution: https://github.com/Ryan-Adams57
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
	[string]$UserName=$Null,
    [string]$Password=$Null,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
	[switch]$IncludeContacts
)

Function Connect_Exo
{
 #Check for EXO module installation
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host "Exchange Online PowerShell module is not available." -ForegroundColor yellow  
  $Confirm = Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
  if($Confirm -match "[yY]") 
  { 
   Write-Host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
  } 
  else 
  { 
   Write-Host "EXO module is required to connect Exchange Online. Please install module using 'Install-Module ExchangeOnlineManagement' cmdlet." 
   Exit
  }
 } 
 Write-Host "Connecting to Exchange Online..."
 
 # Authentication handling based on user inputs
 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
 }
 elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
 {
   Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
 }
 else
 {
  Connect-ExchangeOnline -ShowBanner:$false
 }
}

# Connect to Exchange Online
Connect_Exo

$Location = Get-Location
$OutputCsv = "$Location\DLs_with_ExternalUsers_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$DLWithExternalUsersCount = 0
$DLCount = 0
    
# Process all distribution lists (DLs)
Get-DistributionGroup -ResultSize Unlimited | ForEach{
 $DLCount++
 Write-Progress -Activity "Finding Distribution List with External Users:" -Status "Processed DL Count: $DLCount" -CurrentOperation "Currently Processing DL Name: $_ "
 $DLName = $_.Name
 $DLEmailAddress = $_.PrimarySMTPAddress

 If($IncludeContacts.IsPresent)
 {
  $ExternalUsers = (Get-DistributionGroupMember $_.Name | Where { $_.RecipientType -eq "MailContact" -or $_.RecipientType -eq "MailUser" })
 }
 Else
 {
  $ExternalUsers = (Get-DistributionGroupMember $_.Name | Where { $_.RecipientType -eq "MailUser" })
 }

 # Process DLs with external users
 $ExternalUsersCount = ($ExternalUsers | Measure-Object).Count
 If($ExternalUsersCount -ne '0')
 {
  $EmailAddress = $ExternalUsers.ExternalEmailAddress | ForEach {
    $_.split(":")[1]
  }
  $EmailAddress = $EmailAddress -join (",")
  $ExternalUserName = $ExternalUsers.Name -join ','
  $ExternalUserDisplayName = $ExternalUsers.DisplayName -join ','
  $Result = New-Object PsObject -Property @{
    'DL Name' = $DLName
    'DL Email Address' = $DLEmailAddress
    'No of External Users in DL' = $ExternalUsersCount
    'External Users Name' = $ExternalUserName
    'External Users Display Name' = $ExternalUserDisplayName
    'External Users Email Address' = $EmailAddress
  }
  $Result | Select-Object 'DL Name', 'DL Email Address', 'No of External Users in DL', 'External Users Name', 'External Users Display Name', 'External Users Email Address' | Export-Csv -Path $OutputCsv -NoTypeInformation -Append
  $DLWithExternalUsersCount++
 }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "GitHub - https://github.com/Ryan-Adams57" -ForegroundColor Yellow -NoNewline; Write-Host " for more information. ~~" -ForegroundColor Green `n

# Check if the report file exists and prompt the user to open it
if((Test-Path -Path $OutputCsv) -eq "True") 
{
 Write-Host "$DLWithExternalUsersCount DLs contain external users as members."
 Write-Host "`nDetailed report available in: " -NoNewline -ForegroundColor Yellow; Write-Host $OutputCsv
 $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)   
 If ($UserInput -eq 6)   
 {   
   Invoke-Item "$OutputCsv"   
 } 
}
else
{
 Write-Host "No DLs found with the specific criteria."
}
