<#
=============================================================================================
Name:           Export Microsoft 365 MFA Status Report
Description:    Exports Microsoft 365 MFA status report based on per-user MFA configuration
Version:        2.3
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. Generates reports based on MFA status. 
2. Allows filtering results based on admin users.
3. Supports filtering to display licensed users only.
4. Supports filtering based on sign-in status (allowed/denied).
5. Produces separate output files based on MFA status. 
6. Supports execution with MFA-enabled accounts. 
7. Exports results to CSV files. 
8. Helps identify admin users not protected with MFA.
9. Scheduler-friendly with credential parameter support.
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [switch]$DisabledOnly,
    [switch]$EnabledOnly,
    [switch]$EnforcedOnly,
    [switch]$AdminOnly,
    [switch]$LicensedUserOnly,
    [Nullable[boolean]]$SignInAllowed = $null,
    [string]$UserName,
    [string]$Password
)

$Modules=Get-Module -Name MSOnline -ListAvailable
if($Modules.count -eq 0)
{
  Write-Host "Please install MSOnline module using below command:`nInstall-Module MSOnline" -ForegroundColor Yellow
  Exit
}

if(($UserName -ne "") -and ($Password -ne ""))
{
 $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
 $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
 Connect-MsolService -Credential $Credential
}
else
{
 Connect-MsolService | Out-Null
}

$Result=""
$Results=@()
$UserCount=0
$PrintedUser=0

$ExportCSV=".\MFADisabledUserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$ExportCSVReport=".\MFAEnabledUserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

Get-MsolUser -All | ForEach-Object {

 $UserCount++
 $DisplayName=$_.DisplayName
 $Upn=$_.UserPrincipalName
 $MFAStatus=$_.StrongAuthenticationRequirements.State
 $RolesAssigned=""

 Write-Progress -Activity "`nProcessed user count: $UserCount" -Status "Currently Processing: $DisplayName"

 if($_.BlockCredential -eq "True")
 {
  $SignInStatus="False"
  $SignInStat="Denied"
 }
 else
 {
  $SignInStatus="True"
  $SignInStat="Allowed"
 }

 if(($SignInAllowed -ne $null) -and ([string]$SignInAllowed -ne [string]$SignInStatus))
 {
  return
 }

 if(($LicensedUserOnly.IsPresent) -and ($_.IsLicensed -eq $False))
 {
  return
 }

 if($_.IsLicensed -eq $true)
 {
  $LicenseStat="Licensed"
 }
 else
 {
  $LicenseStat="Unlicensed"
 }

 $Roles=(Get-MsolUserRole -UserPrincipalName $Upn).Name
 if($Roles.count -eq 0)
 {
  $RolesAssigned="No roles"
  $IsAdmin="False"
 }
 else
 {
  $IsAdmin="True"
  foreach($Role in $Roles)
  {
   $RolesAssigned+=$Role
   if($Roles.IndexOf($Role) -lt (($Roles.count)-1))
   {
    $RolesAssigned+=","
   }
  }
 }

 if(($AdminOnly.IsPresent) -and ([string]$IsAdmin -eq "False"))
 {
  return
 }

 if(($MFAStatus -ne $Null) -and (-Not ($DisabledOnly.IsPresent)))
 {
  if(([string]$MFAStatus -eq "Enabled") -and ($EnforcedOnly.IsPresent))
  {
   return
  }

  if(([string]$MFAStatus -eq "Enforced") -and ($EnabledOnly.IsPresent))
  {
   return
  }

  $Methods=""
  $MethodTypes=$_.StrongAuthenticationMethods.MethodType
  $DefaultMFAMethod=($_.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq "True"}).MethodType
  $MFAPhone=$_.StrongAuthenticationUserDetails.PhoneNumber
  $MFAEmail=$_.StrongAuthenticationUserDetails.Email

  if($MFAPhone -eq $Null){ $MFAPhone="-" }
  if($MFAEmail -eq $Null){ $MFAEmail="-" }

  if($MethodTypes -ne $Null)
  {
   $ActivationStatus="Yes"
   foreach($MethodType in $MethodTypes)
   {
    if($Methods -ne "")
    {
     $Methods+=","
    }
    $Methods+=$MethodType
   }
  }
  else
  {
   $ActivationStatus="No"
   $Methods="-"
   $DefaultMFAMethod="-"
   $MFAPhone="-"
   $MFAEmail="-"
  }

  $PrintedUser++
  $Result=@{
    'DisplayName'=$DisplayName
    'UserPrincipalName'=$Upn
    'MFAStatus'=$MFAStatus
    'ActivationStatus'=$ActivationStatus
    'DefaultMFAMethod'=$DefaultMFAMethod
    'AllMFAMethods'=$Methods
    'MFAPhone'=$MFAPhone
    'MFAEmail'=$MFAEmail
    'LicenseStatus'=$LicenseStat
    'IsAdmin'=$IsAdmin
    'AdminRoles'=$RolesAssigned
    'SignInStatus'=$SignInStat
  }

  $Results= New-Object PSObject -Property $Result
  $Results | Select-Object DisplayName,UserPrincipalName,MFAStatus,ActivationStatus,DefaultMFAMethod,AllMFAMethods,MFAPhone,MFAEmail,LicenseStatus,IsAdmin,AdminRoles,SignInStatus |
  Export-Csv -Path $ExportCSVReport -NoTypeInformation -Append
 }

 elseif(($DisabledOnly.IsPresent) -and ($MFAStatus -eq $Null) -and ($_.StrongAuthenticationMethods.MethodType -eq $Null))
 {
  $MFAStatus="Disabled"
  $Department=$_.Department
  if($Department -eq $Null){ $Department="-" }

  $PrintedUser++
  $Result=@{
    'DisplayName'=$DisplayName
    'UserPrincipalName'=$Upn
    'Department'=$Department
    'MFAStatus'=$MFAStatus
    'LicenseStatus'=$LicenseStat
    'IsAdmin'=$IsAdmin
    'AdminRoles'=$RolesAssigned
    'SignInStatus'=$SignInStat
  }

  $Results= New-Object PSObject -Property $Result
  $Results | Select-Object DisplayName,UserPrincipalName,Department,MFAStatus,LicenseStatus,IsAdmin,AdminRoles,SignInStatus |
  Export-Csv -Path $ExportCSV -NoTypeInformation -Append
 }
}

Write-Host "`nScript executed successfully"

if((Test-Path -Path $ExportCSV) -eq "True")
{
 Write-Host "MFA Disabled user report available in:" -NoNewline -ForegroundColor Yellow
 Write-Host $ExportCSV `n 
 $Prompt = New-Object -ComObject wscript.shell
 $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)
 If ($UserInput -eq 6)
 {
  Invoke-Item "$ExportCSV"
 }
 Write-Host "Exported report has $PrintedUser users"
}
elseif((Test-Path -Path $ExportCSVReport) -eq "True")
{
 Write-Host ""
 Write-Host "MFA Enabled user report available in:" -NoNewline -ForegroundColor Yellow
 Write-Host $ExportCSVReport `n
 $Prompt = New-Object -ComObject wscript.shell
 $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)
 If ($UserInput -eq 6)
 {
  Invoke-Item "$ExportCSVReport"
 }
 Write-Host "Exported report has $PrintedUser users"

 Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
 Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Yellow
 Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Yellow
 Write-Host "GitLab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Yellow
 Write-Host "PasteBin: https://pastebin.com/u/Removed_Content`n" -ForegroundColor Yellow
}
Else
{
  Write-Host "No user found that matches your criteria."
}

Get-PSSession | Remove-PSSession
