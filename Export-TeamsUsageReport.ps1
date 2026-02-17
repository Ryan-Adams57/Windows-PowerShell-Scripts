<#
=============================================================================================
Name: Export Teams Usage Report in Microsoft Teams
Version: 1.0
Author: Ryan Adams
Website: https://www.governmentcontrol.net

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. Generates Teams activity reports for periods of 7, 30, 90, or 180 days.    
2. Retrieves Teams usage data for a specific date within the last 28 days. 
3. Identifies inactive teams based on customizable inactivity thresholds.  
4. Automatically verifies and installs the Microsoft Graph PowerShell Module (if not already installed). 
5. Supports Certificate-based Authentication (CBA).   
6. Scheduler-friendly for automated reporting.   
7. Exports results to timestamped CSV files for easy tracking and archival. 

For detailed execution: https://github.com/Ryan-Adams57

=============================================================================================
#> 
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
Param (
    [Parameter(ParameterSetName = 'Period')]
    [ValidateSet('D7', 'D30', 'D90', 'D180')]
    [string]$Period,
    [Parameter(ParameterSetName = 'Date')]
    [string]$ReportDate,
    [Parameter(ParameterSetName = 'Inactive')]
    [ValidatePattern('^\d+$')]
    [int]$InactiveDays,
    [switch]$CreateSession,
    [string]$ClientId,
    [string]$TenantId,
    [string]$CertificateThumbprint
)

Function Connect_ToMgGraph {
    $MsGraphModule = Get-Module Microsoft.Graph -ListAvailable
    if ($MsGraphModule -eq $null) {
        Write-Host "`nImportant: Microsoft Graph module is required to run this script." 
        $confirm = Read-Host "Do you want to install Microsoft Graph module? [Y] Yes [N] No"
        if ($confirm -match "[yY]") {
            Write-Host "Installing Microsoft Graph module..."
            Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
            Write-Host "Microsoft Graph module installed successfully." 
        } else {
            Write-Host "`nMicrosoft Graph module is mandatory. Exiting..." -ForegroundColor Red
            Exit
        }
    }

    Import-Module Microsoft.Graph.Reports -Force

    if ($CreateSession.IsPresent){
        Disconnect-MgGraph | Out-Null
    }
    Write-Host "`nConnecting to Microsoft Graph..."
    if (($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne "")) {
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    } else {
        Connect-MgGraph -Scopes "Reports.Read.All" -NoWelcome -ErrorAction SilentlyContinue
    }

    if ((Get-MgContext) -ne $null) {
        Write-Host "Connected to Microsoft Graph PowerShell Module."
    } else {
        Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red
        Exit
    }
}

Function Export-TeamsActivityCsv {
    param (
        [array]$CsvData,
        [string]$OutputPath
    )

    if ($CsvData.Count -eq 0) { return }
	
    $CsvData = $CsvData | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_.'Last Activity Date')) { $_.'Last Activity Date' = 'Never Active' }
        $_   
    }

    $CsvData | Select-Object "Team Name", "Team Id", "Team Type", "Is Deleted", "Last Activity Date","Active Users", 
        @{ Name = "Active External Users"; Expression = { $_."Active External Users" } }, 
        @{ Name = "Active Guests"; Expression = { $_."Guests" } }, "Active Channels", "Active Shared Channels", 
        "Post Messages", "Urgent Messages", "Mentions", "Channel Messages", "Reply Messages", "Reactions", "Meetings Organized" | 
        Export-Csv -Path $OutputPath -NoTypeInformation
}

Connect_ToMgGraph
$Location = Get-Location
$TempFilePath = "$Location\Teams_Activity_Summary_Report_Temp_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$CsvFilePath = "$Location\Teams_Activity_Summary_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"

if (-not ($Period -or $ReportDate -or $InactiveDays)) {
    Write-Host `n"We can perform the following operations:" -ForegroundColor Cyan
    Write-Host "      1. Audit Teams activity for a period of time" -ForegroundColor Yellow
    Write-Host "      2. Get Teams activity for a specific day" -ForegroundColor Yellow
    Write-Host "      3. Find Inactive Teams" -ForegroundColor Yellow
    Write-Host "      4. Exit" -ForegroundColor Yellow

    [int]$Action = Read-Host "`nPlease choose the action to continue"
}
else {
    if ($Period) { $Action = 1 } elseif ($ReportDate) { $Action = 2 } elseif ($InactiveDays) { $Action = 3 }
}

Switch ($Action) {
    1 {
        $validPeriods = @("D7", "D30", "D90", "D180")

        if (!$Period) {
            Write-Host "`nAvailable periods: $($validPeriods -join ', ')"
            $Period = (Read-Host "Enter your preferred period (e.g., D30)").Trim().ToUpper()
        }

        if ($validPeriods -contains $Period) {
            Get-MgReportTeamActivityDetail -Period $Period -OutFile $TempFilePath
            $csvdata = Import-Csv -Path $TempFilePath
            Export-TeamsActivityCsv -CsvData $csvdata -OutputPath $CsvFilePath
        } else {
            Write-Host "Invalid period entered." -ForegroundColor Red
            Exit
        }
    }

    2 {
        if (!$ReportDate) { 
            $ReportDate = Read-Host "`nEnter a date starting from $((Get-Date).AddDays(-28).ToString('yyyy-MM-dd'))" 
        }
        try {
            Get-MgReportTeamActivityDetail -Date $ReportDate -OutFile $TempFilePath -ErrorAction Stop
            $csvdata = Import-Csv -Path $TempFilePath
            Export-TeamsActivityCsv -CsvData $csvdata -OutputPath $CsvFilePath
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    3 {
        if (!$InactiveDays) {
            $InactiveDays = Read-Host "`nEnter number of inactive days"
        }

        Get-MgReportTeamActivityDetail -Period 'D180' -OutFile $TempFilePath
        $csvdata = Import-Csv -Path $TempFilePath
        $cutoffDate = (Get-Date).AddDays(-[int]$InactiveDays)
        $inactiveData = $csvdata | Where-Object {
            if ($_. 'Is Deleted' -eq $true) { return $false }
            if (-not [string]::IsNullOrWhiteSpace($_.'Last Activity Date')) {
                try {
                    $lastActivity = Get-Date $_.'Last Activity Date' -ErrorAction Stop
                    return ($lastActivity -lt $cutoffDate)
                }
                catch { return $true }
            }
            return $true
        }
        
        Export-TeamsActivityCsv -CsvData $inactiveData -OutputPath $CsvFilePath
    }
    4 { 
        Disconnect-MgGraph | Out-Null
        Exit 
    }
    default {
        Write-Host "`nInvalid choice. Please select a valid action." -ForegroundColor Red
        Exit
    }
}

Disconnect-MgGraph | Out-Null

if((Test-Path -Path $CsvFilePath) -and ((Get-Content $CsvFilePath | Where-Object { $_ -match '\S' }) -ne $null)) {   
    Remove-Item -Path $TempFilePath -ErrorAction SilentlyContinue
    Write-Host "`nThe output file is available at: " -NoNewline -ForegroundColor Yellow; Write-Host "$CsvFilePath" 
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the output file?", 0,"Open Output File",4)
    if ($UserInput -eq 6) {
        Invoke-Item "$CsvFilePath"
    }
} else {
    Write-Host "`nNo records found." 
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "~~ Visit https://github.com/Ryan-Adams57 for more Microsoft 365 scripts and reporting utilities. ~~" -ForegroundColor Green
