<#
=============================================================================================
Name:           Teams Private Channel Administration & Reporting Toolkit
Description:    This script performs Private Channel related management actions and reporting
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

To run the script
./TeamsChannelGovernanceAndReportingTool.ps1

To schedule/run the script by explicitly mentioning credential
./TeamsChannelGovernanceAndReportingTool.ps1 -UserName <UserName> -Password <Password>

To run the script with certificate based authentication
./TeamsChannelGovernanceAndReportingTool.ps1 -TenantId <TenantId> -AppId <AppId> -CertificateThumbPrint <CertThumbPrint>

To run a specific action directly
./TeamsChannelGovernanceAndReportingTool.ps1 -Action 7

Change Log
~~~~~~~~~~
 V1.0 (Nov 18, 2019) - File created
 V2.0 (Nov 13, 2024) - Added support for certificate-based authentication, removed older PowerShell modules, and minor usability enhancements
=============================================================================================
#>

param(
[string]$UserName, 
[string]$Password, 
[string]$TenantId,
[string]$AppId,
[string]$CertificateThumbprint,
[int]$Action
) 

Function MSTeam_PSModule
{
 $Module = Get-Module -Name MicrosoftTeams -ListAvailable 
 if($Module.Count -eq 0)
 {
  Write-Host MicrosoftTeams module is not available -ForegroundColor Yellow 
  $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
  if($Confirm -match "[yY]")
  {
   Install-Module MicrosoftTeams -Scope CurrentUser
  }
  else
  {
   Write-Host "MicrosoftTeams module is required. Please install module using Install-Module MicrosoftTeams cmdlet."
   Exit
  }
 }

 Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Yellow

 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  $Team = Connect-MicrosoftTeams -Credential $Credential
 }
 elseif(($TenantId -ne "") -and ($AppId -ne "") -and ($CertificateThumbprint -ne ""))  
 {  
  $Team = Connect-MicrosoftTeams -TenantId $TenantId -ApplicationId $AppId -CertificateThumbprint $CertificateThumbprint 
 }
 else
 {  
  $Team = Connect-MicrosoftTeams
 }

 If($Team -eq $null)
 {
  Write-Host "Error occurred while creating Teams session. Please try again" -ForegroundColor Red
  Exit
 }
}

Function Open_Output
{
 if((Test-Path -Path $Path) -eq $true) 
 {
  Write-Host "`nThe exported report is available at:" -ForegroundColor Yellow
  Write-Host $Path -ForegroundColor Cyan

  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open the output file?",0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$Path"   
  } 
 }
 else
 {
  Write-Host "No data found."
 }
}

MSTeam_PSModule
$Location = Get-Location
[boolean]$Delay = $false

Do {
 if($Action -eq "")
 {
  if($Delay -eq $true)
  {
   Start-Sleep -Seconds 2
  }
  $Delay = $true

  Write-Host ""
  Write-Host "`nPrivate Channel Management" -ForegroundColor Yellow
  Write-Host "    1.Allow for Organization" -ForegroundColor Cyan
  Write-Host "    2.Disable for Organization" -ForegroundColor Cyan
  Write-Host "    3.Allow for a User" -ForegroundColor Cyan
  Write-Host "    4.Disable for a User" -ForegroundColor Cyan
  Write-Host "    5.Allow User in bulk using CSV import" -ForegroundColor Cyan
  Write-Host "    6.Disable User in bulk using CSV import" -ForegroundColor Cyan

  Write-Host "`nPrivate Channel Reporting" -ForegroundColor Yellow
  Write-Host "    7.All Private Channels in Organization" -ForegroundColor Cyan
  Write-Host "    8.All Private Channels in Teams" -ForegroundColor Cyan
  Write-Host "    9.Members and Owners Report of All Private Channels" -ForegroundColor Cyan
  Write-Host "    10.Members and Owners Report of Single Private Channel" -ForegroundColor Cyan
  Write-Host "    0.Exit" -ForegroundColor Cyan
  Write-Host ""

  $i = Read-Host "Please choose the action to continue" 
 }
 else
 {
  $i = $Action
 }

 Switch ($i) {

  1 {
     Set-CsTeamsChannelsPolicy -Identity Global –AllowPrivateChannelCreation $True 
     Write-Host "Private Channel creation allowed organization-wide" -ForegroundColor Green    
    }
      
  2 {
     Set-CsTeamsChannelsPolicy -Identity Global –AllowPrivateChannelCreation $False 
     Write-Host "Private Channel creation blocked organization-wide" -ForegroundColor Green 
    }

  3 {
     if((Get-CsTeamsChannelsPolicy -Identity "Allow Private Channel Creation" -ErrorAction SilentlyContinue) -eq $null)
     {
      New-CsTeamsChannelsPolicy -Identity "Allow Private Channel Creation" -AllowPrivateChannelCreation $True | Out-Null
     }  
     $User = Read-Host "Enter User name (UPN format) to grant private channel creation rights"
     Grant-CsTeamsChannelsPolicy -PolicyName "Allow Private Channel Creation" -Identity $User 
     if($?)
     {
      Write-Host "`n$User can now create Private Channels" -ForegroundColor Green
     }  
    }

  4 {
     if((Get-CsTeamsChannelsPolicy -Identity "Disable Private Channel Creation" -ErrorAction SilentlyContinue) -eq $null)
     {
      New-CsTeamsChannelsPolicy -Identity "Disable Private Channel Creation" -AllowPrivateChannelCreation $False | Out-Null
     }  
     $User = Read-Host "Enter User name (UPN format) to disable private channel creation"
     Grant-CsTeamsChannelsPolicy -PolicyName "Disable Private Channel Creation" -Identity $User
     if($?)
     {
      Write-Host "`nPrivate Channel creation blocked for $User" -ForegroundColor Green
     }
    }

  5 {
     if((Get-CsTeamsChannelsPolicy -Identity "Allow Private Channel Creation" -ErrorAction SilentlyContinue) -eq $null)
     {
      New-CsTeamsChannelsPolicy -Identity "Allow Private Channel Creation" -AllowPrivateChannelCreation $True
     }
     Write-Host "`nThe file must contain User UPNs separated by new lines (no header required)." -ForegroundColor Magenta
     $UserNamesFile = Read-Host "Enter CSV/txt file path (Eg:C:\Users\Desktop\UserNames.txt)"
     $Users = Import-Csv -Header "UserPrincipalName" $UserNamesFile
     foreach($User in $Users)
     {
      Grant-CsTeamsChannelsPolicy -PolicyName "Allow Private Channel Creation" -Identity $User.UserPrincipalName
      if($?)
      {
       Write-Host "$($User.UserPrincipalName) can now create Private Channels" -ForegroundColor Green
      }
     }
    }   

  6 {
     if((Get-CsTeamsChannelsPolicy -Identity "Disable Private Channel Creation" -ErrorAction SilentlyContinue) -eq $null)
     {
      New-CsTeamsChannelsPolicy -Identity "Disable Private Channel Creation" -AllowPrivateChannelCreation $False
     }
     Write-Host "`nThe file must contain User UPNs separated by new lines (no header required)." -ForegroundColor Magenta
     $UserNamesFile = Read-Host "Enter CSV/txt file path (Eg:C:\Users\Desktop\UserNames.txt)"
     $Users = Import-Csv -Header "UserPrincipalName" $UserNamesFile
     foreach($User in $Users)
     {
      Grant-CsTeamsChannelsPolicy -PolicyName "Disable Private Channel Creation" -Identity $User.UserPrincipalName
      if($?)
      {
       Write-Host "Private Channel creation blocked for $($User.UserPrincipalName)" -ForegroundColor Green
      }
     } 
    }
       
   7 {
      $Path = "$Location/PrivateChannelsReport_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
      Write-Host "Exporting Private Channels report..."
      $Count = 0

      Get-Team | ForEach-Object {
       $TeamName = $_.DisplayName
       $Count++
       Write-Progress -Activity "Processed Teams count: $Count" -Status "Currently Processing: $TeamName"
       $GroupId = $_.GroupId
       $PrivateChannels = (Get-TeamChannel -GroupId $GroupId -MembershipType Private).DisplayName
       foreach($PrivateChannel in $PrivateChannels)
       {
        [PSCustomObject]@{
         'Teams Name'     = $TeamName
         'Private Channel' = $PrivateChannel
        } | Export-Csv $Path -NoTypeInformation -Append
       }
      }

      Write-Progress -Activity "Completed" -Completed
      Open_Output
    }  

   8 {
      $TeamName = Read-Host "Enter Teams name (Case Sensitive)"
      Write-Host "Exporting Private Channel report..."
      $GroupId = (Get-Team -DisplayName $TeamName).GroupId
      $Path = "$Location\PrivateChannels_$($TeamName)_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

      Get-TeamChannel -GroupId $GroupId -MembershipType Private |
       Select-Object DisplayName |
       Export-Csv $Path -NoTypeInformation

      Open_Output
     }

   9{
     Write-Host "Exporting all Private Channels Members and Owners report..."
     $Count = 0
     $Path = "$Location/AllPrivateChannels_MembersAndOwners_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

     Get-Team | ForEach-Object {
      $TeamName = $_.DisplayName
      $GroupId = $_.GroupId
      $PrivateChannels = (Get-TeamChannel -GroupId $GroupId -MembershipType Private).DisplayName
      foreach($PrivateChannel in $PrivateChannels)
      {
       $Count++
       Write-Progress -Activity "Processed Private Channel count: $Count" -Status "Currently Processing: $PrivateChannel"
       Get-TeamChannelUser -GroupId $GroupId -DisplayName $PrivateChannel | ForEach-Object {
        [PSCustomObject]@{
         'Teams Name'           = $TeamName
         'Private Channel Name' = $PrivateChannel
         'UPN'                  = $_.User
         'User Display Name'    = $_.Name
         'Role'                 = $_.Role
        } | Export-Csv $Path -NoTypeInformation -Append
       }
      }    
     }

     Write-Progress -Activity "Completed" -Completed
     Open_Output
    }    

   10 {
    $TeamName = Read-Host "Enter Teams name in which Private Channel resides (Case Sensitive)"
    $ChannelName = Read-Host "Enter Private Channel name"
    $GroupId = (Get-Team -DisplayName $TeamName).GroupId 
    Write-Host "Exporting $ChannelName Members and Owners report..."
    $Path = "$Location\MembersOf_$($ChannelName)_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

    Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName | ForEach-Object {
     [PSCustomObject]@{
      'Teams Name'           = $TeamName
      'Private Channel Name' = $ChannelName
      'UPN'                  = $_.User
      'User Display Name'    = $_.Name
      'Role'                 = $_.Role
     } | Export-Csv $Path -NoTypeInformation -Append
    }

    Open_Output
   }
  }

  if($Action -ne "")
  {
   Exit
  }

 } While ($i -ne 0)
