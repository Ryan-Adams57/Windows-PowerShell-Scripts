<#
=============================================================================================
Name:           Teams Enterprise Reporting Console
Description:    This script exports Microsoft Teams reports to CSV
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights:
~~~~~~~~~~~~~~~~~
1. A single script allows you to generate eight different Teams reports.
2. The script can be executed with MFA enabled accounts.
3. Exports output to CSV.
4. Automatically installs Microsoft Teams PowerShell module (if not installed already) upon confirmation.
5. Scheduler friendly. Credential can be passed as a parameter instead of saving inside the script.
6. Supports certificate-based authentication.
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

# Connect to Microsoft Teams
$Module = Get-Module -Name MicrosoftTeams -ListAvailable 
if($Module.Count -eq 0)
{
 Write-Host "MicrosoftTeams module is not available" -ForegroundColor Yellow 
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

Write-Host "Importing Microsoft Teams module..." -ForegroundColor Yellow

# Authentication
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

If($Team -ne $null)
{
 Write-Host "`nSuccessfully connected to Microsoft Teams" -ForegroundColor Green
}
else
{
 Write-Host "Error occurred while creating Teams session. Please try again" -ForegroundColor Red
 Exit
}

[boolean]$Delay = $false
Do {
 if($Action -eq "")
 {
  if($Delay) { Start-Sleep -Seconds 2 }
  $Delay = $true

  Write-Host ""
  Write-Host "`nMicrosoft Teams Reporting" -ForegroundColor Yellow
  Write-Host "    1.All Teams in organization" -ForegroundColor Cyan
  Write-Host "    2.All Teams members and owners report" -ForegroundColor Cyan
  Write-Host "    3.Specific Team members and owners report" -ForegroundColor Cyan
  Write-Host "    4.All Teams owners report" -ForegroundColor Cyan
  Write-Host "    5.Specific Team owners report" -ForegroundColor Cyan

  Write-Host "`nTeams Channel Reporting" -ForegroundColor Yellow
  Write-Host "    6.All channels in an organization" -ForegroundColor Cyan
  Write-Host "    7.All channels in a specific Team" -ForegroundColor Cyan
  Write-Host "    8.Members and Owners Report of a Single Channel" -ForegroundColor Cyan
  Write-Host "    0.Exit" -ForegroundColor Cyan

  $i = Read-Host "`nPlease choose the action to continue"
 }
 else
 {
  $i = $Action
 }

 Switch ($i) {

  1 {
     $Path = "./All_Teams_Report_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"
     Write-Host "Exporting all Teams report..."
     $Count = 0

     Get-Team | ForEach-Object {
       $TeamName = $_.DisplayName
       Write-Progress -Activity "Processed Teams count: $Count" -Status "Currently Processing: $TeamName"
       $Count++

       $GroupId = $_.GroupId
       $TeamUser = Get-TeamUser -GroupId $GroupId

       [PSCustomObject]@{
        'Teams Name'          = $TeamName
        'Team Type'           = $_.Visibility
        'Mail Nick Name'      = $_.MailNickName
        'Description'         = $_.Description
        'Archived Status'     = $_.Archived
        'Channel Count'       = (Get-TeamChannel -GroupId $GroupId).Count
        'Team Members Count'  = $TeamUser.Count
        'Team Owners Count'   = ($TeamUser | Where-Object {$_.Role -eq "Owner"}).Count
       } | Export-Csv $Path -NoTypeInformation -Append
     }

     Write-Progress -Activity "Completed" -Completed
     Write-Host "`nReport available in $Path" -ForegroundColor Green
    }

  2 {
     $Path = "./All_Teams_Members_And_Owners_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"
     Write-Host "Exporting all Teams members and owners report..."
     $Count = 0

     Get-Team | ForEach-Object {
      $TeamName = $_.DisplayName
      Write-Progress -Activity "Processed Teams count: $Count" -Status "Currently Processing: $TeamName"
      $Count++
      $GroupId = $_.GroupId

      Get-TeamUser -GroupId $GroupId | ForEach-Object {
       [PSCustomObject]@{
        'Teams Name'  = $TeamName
        'Member Name' = $_.Name
        'Member Mail' = $_.User
        'Role'        = $_.Role
       } | Export-Csv $Path -NoTypeInformation -Append
      }
     }

     Write-Progress -Activity "Completed" -Completed
     Write-Host "`nReport available in $Path" -ForegroundColor Green
    }

  3 {
     $TeamName = Read-Host "Enter Teams name to get members report (Case sensitive)"
     $GroupId = (Get-Team -DisplayName $TeamName).GroupId 
     $Path = ".\MembersOf_${TeamName}_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"

     Write-Host "Exporting $TeamName Members and Owners report..."

     Get-TeamUser -GroupId $GroupId | ForEach-Object {
      [PSCustomObject]@{
       'Member Name' = $_.Name
       'Member Mail' = $_.User
       'Role'        = $_.Role
      } | Export-Csv $Path -NoTypeInformation -Append
     }

     Write-Host "`nReport available in $Path" -ForegroundColor Green
    }

  4 {
     $Path = "./All_Teams_Owners_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"
     Write-Host "Exporting all Teams owner report..."
     $Count = 0

     Get-Team | ForEach-Object {
      $TeamName = $_.DisplayName
      Write-Progress -Activity "Processed Teams count: $Count" -Status "Currently Processing: $TeamName"
      $Count++
      $GroupId = $_.GroupId

      Get-TeamUser -GroupId $GroupId | Where-Object {$_.Role -eq "Owner"} | ForEach-Object {
       [PSCustomObject]@{
        'Teams Name' = $TeamName
        'Owner Name' = $_.Name
        'Owner Mail' = $_.User
       } | Export-Csv $Path -NoTypeInformation -Append
      }
     }

     Write-Progress -Activity "Completed" -Completed
     Write-Host "`nReport available in $Path" -ForegroundColor Green
    }

  5 {
     $TeamName = Read-Host "Enter Teams name to get owners report (Case sensitive)"
     $GroupId = (Get-Team -DisplayName $TeamName).GroupId 
     $Path = ".\OwnersOf_${TeamName}_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"

     Write-Host "Exporting $TeamName Owners report..."

     Get-TeamUser -GroupId $GroupId | Where-Object {$_.Role -eq "Owner"} | ForEach-Object {
      [PSCustomObject]@{
       'Member Name' = $_.Name
       'Member Mail' = $_.User
      } | Export-Csv $Path -NoTypeInformation -Append
     }

     Write-Host "`nReport available in $Path" -ForegroundColor Green
    }

  6 {
      $Path = "./All_Channels_Report_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"
      Write-Host "Exporting all Channels report..."
      $Count = 0

      Get-Team | ForEach-Object {
       $TeamName = $_.DisplayName
       Write-Progress -Activity "Processed Teams count: $Count" -Status "Currently Processing Team: $TeamName"
       $Count++
       $GroupId = $_.GroupId

       Get-TeamChannel -GroupId $GroupId | ForEach-Object {
        $ChannelName = $_.DisplayName
        $ChannelUser = Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName

        [PSCustomObject]@{
         'Teams Name'          = $TeamName
         'Channel Name'        = $ChannelName
         'Membership Type'     = $_.MembershipType
         'Description'         = $_.Description
         'Owners Count'        = ($ChannelUser | Where-Object {$_.Role -eq "Owner"}).Count
         'Total Members Count' = $ChannelUser.Count
        } | Export-Csv $Path -NoTypeInformation -Append
       }
      }

      Write-Host "`nReport available in $Path" -ForegroundColor Green
     }  

   7 {
      $TeamName = Read-Host "Enter Teams name (Case Sensitive)"
      $GroupId = (Get-Team -DisplayName $TeamName).GroupId
      $Path = ".\Channels_${TeamName}_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"

      Write-Host "Exporting Channels report..."

      Get-TeamChannel -GroupId $GroupId | ForEach-Object {
       $ChannelName = $_.DisplayName
       $ChannelUser = Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName

       [PSCustomObject]@{
        'Teams Name'          = $TeamName
        'Channel Name'        = $ChannelName
        'Membership Type'     = $_.MembershipType
        'Description'         = $_.Description
        'Owners Count'        = ($ChannelUser | Where-Object {$_.Role -eq "Owner"}).Count
        'Total Members Count' = $ChannelUser.Count
       } | Export-Csv $Path -NoTypeInformation -Append
      }

      Write-Host "`nReport available in $Path" -ForegroundColor Green
     }  
    
   8 {
      $TeamName = Read-Host "Enter Teams name in which Channel resides (Case sensitive)"
      $ChannelName = Read-Host "Enter Channel name"
      $GroupId = (Get-Team -DisplayName $TeamName).GroupId 
      $Path = ".\MembersOf_${ChannelName}_$((Get-Date -Format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"

      Write-Host "Exporting $ChannelName Members and Owners report..."

      Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName | ForEach-Object {
       [PSCustomObject]@{
        'Teams Name'  = $TeamName
        'Channel Name'= $ChannelName
        'Member Name' = $_.Name
        'Member Mail' = $_.User
        'Role'        = $_.Role
       } | Export-Csv $Path -NoTypeInformation -Append
      }

      Write-Host "`nReport available in $Path" -ForegroundColor Green
     }
   }

   if($Action -ne "") { Exit
