<#
=============================================================================================
Name:           Export MS Teams Private Channels and Membership Report
Description:    This script exports 7 private channel reports
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. A single script allows you to generate 7 different Private channels reports.  
2. The script can be executed with MFA enabled accounts too. 
3. Exports output to CSV. 
4. Automatically installs Microsoft Teams PowerShell module (if not installed already) upon user confirmation. 
5. The script is scheduler friendly; credentials can be passed as parameters.
6. Supports certificate-based authentication. 
============================================================================================
#>

# Accept input parameters 
param(
    [string]$UserName, 
    [string]$Password, 
    [string]$TenantId,
    [string]$AppId,
    [string]$CertificateThumbprint,
    [int]$Action
) 

Function CheckOutput {
    if ((Test-Path -Path $Path) -eq $true) {
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        if ($UserInput -eq 6) {
            Invoke-Item "$Path"
        }
        Write-Host "Detailed report available in: $Path" -ForegroundColor Green
    } else {
        Write-Host "No data found" -ForegroundColor Red
    }
}

# Connect to Microsoft Teams
$Module = Get-Module -Name MicrosoftTeams -ListAvailable 
if ($Module.count -eq 0) {
    Write-Host "MicrosoftTeams module is not available" -ForegroundColor Yellow
    $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
    if ($Confirm -match "[yY]") {
        Install-Module MicrosoftTeams -Scope CurrentUser
    } else {
        Write-Host "Microsoft Teams module is required. Please install module using Install-Module MicrosoftTeams cmdlet."
        Exit
    }
}
Write-Host "Importing Microsoft Teams module..." -ForegroundColor Yellow
Import-Module MicrosoftTeams

# Storing credential for scheduling purposes or passing as parameter
if (($UserName -ne "") -and ($Password -ne "")) {
    $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
    $Credential  = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
    $Team = Connect-MicrosoftTeams -Credential $Credential
}
# Authentication using certificate-based auth
elseif (($TenantId -ne "") -and ($AppId -ne "") -and ($CertificateThumbprint -ne "")) {  
    $Team = Connect-MicrosoftTeams -TenantId $TenantId -ApplicationId $AppId -CertificateThumbprint $CertificateThumbprint 
}
else {  
    $Team = Connect-MicrosoftTeams
}

# Check Teams connectivity
if ($Team -ne $null) {
    Write-Host "`nSuccessfully connected to Microsoft Teams" -ForegroundColor Green
} else {
    Write-Host "Error occurred while creating Teams session. Please try again." -ForegroundColor Red
    Exit
}

[boolean]$Delay = $false
Do {
    if ($Action -eq "") {
        if ($Delay -eq $true) { Start-Sleep -Seconds 2 }
        $Delay = $true
        Write-Host ""
        Write-Host "`nMicrosoft Teams Private Channel Reporting" -ForegroundColor Yellow
        Write-Host "    1. Export all Private Channels" -ForegroundColor Cyan
        Write-Host "    2. Export Private Channels in a specific team" -ForegroundColor Cyan
        Write-Host "    3. Export all Private Channels & their membership report" -ForegroundColor Cyan
        Write-Host "    4. Export membership of Private Channels in a Specific team" -ForegroundColor Cyan
        Write-Host "    5. Export Private Channels' owners report" -ForegroundColor Cyan
        Write-Host "    6. Export Private Channels with guests" -ForegroundColor Cyan
        Write-Host "    7. Export all teams with Private Channels" -ForegroundColor Cyan
        Write-Host "    0. Exit" -ForegroundColor Cyan

        $i = Read-Host "`nPlease choose the action to continue"
    } else {
        $i = $Action
    }

    $Location = Get-Location
    Switch ($i) {
        1 {
            $Results = @() 
            $Path = "$Location\All_Private_Channels_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Write-Host "Exporting private Channels report..."
            $Count = 0
            Get-Team | ForEach-Object {
                $TeamName = $_.DisplayName
                Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing Team: $TeamName"
                $Count++
                $GroupId = $_.GroupId
                Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                    $ChannelName = $_.DisplayName
                    Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing Team: $TeamName, Channel: $ChannelName"
                    $MembershipType = $_.MembershipType
                    $Description = $_.Description
                    $ChannelUser = Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName
                    $ChannelMemberCount = $ChannelUser.Count
                    $ChannelOwnerCount = ($ChannelUser | Where-Object { $_.Role -eq "Owner" }).Count
                    $ChannelGuestCount = ($ChannelUser | Where-Object { $_.Role -eq "Guest" }).Count
                    $Result = @{
                        'Teams Name' = $TeamName
                        'Channel Name' = $ChannelName
                        'Membership Type' = $MembershipType
                        'Description' = $Description
                        'Total Members Count' = $ChannelMemberCount
                        'Owners Count' = $ChannelOwnerCount
                        'Guests Count' = $ChannelGuestCount
                    }
                    $Results = New-Object PSObject -Property $Result
                    $Results | Select-Object 'Teams Name','Channel Name','Membership Type','Description','Owners Count','Guests Count','Total Members Count' | Export-Csv $Path -NoTypeInformation -Append
                }
            }
            Write-Progress -Activity "`nProcessed Teams count: $Count" -Completed
            CheckOutput
        }

        2 {
            $TeamName = Read-Host "Enter Team name (Case Sensitive)"
            Write-Host "Exporting private channels..."
            $Count = 0
            $GroupId = (Get-Team -DisplayName $TeamName).GroupId
            $Path = "$Location\PrivateChannels_in_$TeamName_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                $ChannelName = $_.DisplayName
                Write-Progress -Activity "`nProcessed channel count: $Count" -Status "Currently Processing Channel: $ChannelName"
                $Count++
                $MembershipType = $_.MembershipType
                $Description = $_.Description
                $ChannelUser = Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName
                $ChannelMemberCount = $ChannelUser.Count
                $ChannelOwnerCount = ($ChannelUser | Where-Object { $_.Role -eq "Owner" }).Count
                $Result = @{
                    'Teams Name' = $TeamName
                    'Channel Name' = $ChannelName
                    'Membership Type' = $MembershipType
                    'Description' = $Description
                    'Owners Count' = $ChannelOwnerCount
                    'Total Members Count' = $ChannelMemberCount
                }
                $Results = New-Object PSObject -Property $Result
                $Results | Select-Object 'Teams Name','Channel Name','Membership Type','Description','Owners Count','Total Members Count' | Export-Csv $Path -NoTypeInformation -Append
            }
            Write-Progress -Activity "`nProcessed channel count: $Count" -Completed
            CheckOutput
        }

        3 {
            $Results = @() 
            Write-Host "Exporting all Teams members and owners report..."
            $Count = 0
            $Path = "$Location\PrivateChannels_Membership_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-Team | ForEach-Object {
                $TeamName = $_.DisplayName
                Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing: $TeamName"
                $Count++
                $GroupId = $_.GroupId
                Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                    $ChannelName = $_.DisplayName
                    Write-Progress -Activity "`nProcessed channel count: $Count" -Status "Currently Processing Channel: $ChannelName"
                    $Count++
                    Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName | ForEach-Object {
                        $Name = $_.Name
                        $MemberMail = $_.User
                        $Role = $_.Role
                        $Result = @{
                            'Teams Name' = $TeamName
                            'Channel Name' = $ChannelName
                            'Member Name' = $Name
                            'Member Mail' = $MemberMail
                            'Role' = $Role
                        }
                        $Results = New-Object PSObject -Property $Result
                        $Results | Select-Object 'Teams Name','Channel Name','Member Name','Member Mail','Role' | Export-Csv $Path -NoTypeInformation -Append
                    }
                }
            }
            Write-Progress -Activity "`nProcessed Teams count: $Count" -Completed
            CheckOutput
        }

        4 {
            $Results = @() 
            Write-Host "Exporting membership of Private Channels in a specific team..."
            $Count = 0
            $TeamName = Read-Host "Enter Team name in which Channel resides (Case Sensitive)"
            $GroupId = (Get-Team -DisplayName $TeamName).GroupId 
            $Path = "$Location\Membership_Report_PrivateChannels_in_$TeamName_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                $Count++
                $ChannelName = $_.DisplayName
                Write-Progress -Activity "`nProcessed channel count: $Count" -Status "Currently Processing Channel: $ChannelName"
                $MembershipType = $_.MembershipType
                $Description = $_.Description
                Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName | ForEach-Object {
                    $Name = $_.Name
                    $MemberMail = $_.User
                    $Role = $_.Role
                    $Result = @{
                        'Teams Name' = $TeamName
                        'Channel Name' = $ChannelName
                        'Member Name' = $Name
                        'Member Mail' = $MemberMail
                        'Role' = $Role
                    }
                    $Results = New-Object PSObject -Property $Result
                    $Results | Select-Object 'Channel Name','Member Name','Member Mail','Role','Teams Name' | Export-Csv $Path -NoTypeInformation -Append
                }
            }
            Write-Progress -Activity "`nProcessed channel count: $Count" -Completed
            CheckOutput
        }

        5 {
            $Results = @() 
            Write-Host "Exporting private channels' owner report..."
            $Count = 0
            $Path = "$Location\PrivateChannels_Ownership_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-Team | ForEach-Object {
                $TeamName = $_.DisplayName
                Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing: $TeamName"
                $Count++
                $GroupId = $_.GroupId
                Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                    $ChannelName = $_.DisplayName
                    Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing Channel: $ChannelName"
                    $Count++
                    Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName -Role Owner | ForEach-Object {
                        $Name = $_.Name
                        $MemberMail = $_.User
                        $Role = $_.Role
                        $Result = @{
                            'Teams Name' = $TeamName
                            'Channel Name' = $ChannelName
                            'Member Name' = $Name
                            'Member Mail' = $MemberMail
                            'Role' = $Role
                        }
                        $Results = New-Object PSObject -Property $Result
                        $Results | Select-Object 'Teams Name','Channel Name','Member Name','Member Mail','Role' | Export-Csv $Path -NoTypeInformation -Append
                    }
                }
            }
            Write-Progress -Activity "`nProcessed Teams count: $Count" -Completed
            CheckOutput
        }

        6 {
            $Results = @() 
            Write-Host "Exporting private channels' with guest users..."
            $Count = 0
            $Path = "$Location\PrivateChannels_with_Guests_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-Team | ForEach-Object {
                $TeamName = $_.DisplayName
                Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing: $TeamName"
                $Count++
                $GroupId = $_.GroupId
                Get-TeamChannel -GroupId $GroupId -MembershipType Private | ForEach-Object {
                    $ChannelName = $_.DisplayName
                    Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing Channel: $ChannelName"
                    $Count++
                    Get-TeamChannelUser -GroupId $GroupId -DisplayName $ChannelName -Role Guest | ForEach-Object {
                        $Name = $_.Name
                        $MemberMail = $_.User
                        $Role = $_.Role
                        $Result = @{
                            'Teams Name' = $TeamName
                            'Channel Name' = $ChannelName
                            'Guest Name' = $Name
                            'Guest Mail' = $MemberMail
                            'Role' = $Role
                        }
                        $Results = New-Object PSObject -Property $Result
                        $Results | Select-Object 'Teams Name','Channel Name','Guest Name','Guest Mail','Role' | Export-Csv $Path -NoTypeInformation -Append
                    }
                }
            }
            Write-Progress -Activity "`nProcessed Teams count: $Count" -Completed
            CheckOutput
        }

        7 {
            $Results = @() 
            Write-Host "Exporting teams with private Channels..."
            $Count = 0
            $Path = "$Location\All_Teams_with_Private_Channels_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
            Get-Team | ForEach-Object {
                $TeamName = $_.DisplayName
                Write-Progress -Activity "`nProcessed Teams count: $Count" -Status "Currently Processing Team: $TeamName"
                $Count++
                $GroupId = $_.GroupId
                $PrivateChannels = (Get-TeamChannel -GroupId $GroupId -MembershipType Private).DisplayName
                $PrivateChannelsCount = $PrivateChannels.Count
                $PrivateChannelsName = $PrivateChannels -join ","
                if ($PrivateChannelsCount -gt 0) {
                    $Result = @{
                        'Teams Name' = $TeamName
                        'Private Channels Count' = $PrivateChannelsCount
                        'Private Channel Names' = $PrivateChannelsName
                    }
                    $Results = New-Object PSObject -Property $Result
                    $Results | Select-Object 'Teams Name','Private Channels Count','Private Channel Names' | Export-Csv $Path -NoTypeInformation -Append
                }
            }
            Write-Progress -Activity "`nProcessed Teams count: $Count" -Completed
            CheckOutput
        }
    }
    if ($Action -ne "") { exit }
} While ($i -ne 0)
Clear-Host
