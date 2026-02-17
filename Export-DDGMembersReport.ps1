<#
=============================================================================================
Name:           Export Dynamic Distribution Group Members Report
Version:        2.0
Website:        https://www.governmentcontrol.net/

Author:
~~~~~~~~~~~
Ryan Adams
GitHub - https://github.com/Ryan-Adams57
Gitlab https://gitlab.com/Ryan-Adams57
PasteBin https://pastebin.com/u/Removed_Content

Highlights:
~~~~~~~~~~~
1. Supports MFA-enabled accounts.
2. Filter output by group size.
3. Export members of all DDGs or specific groups from input file.
4. Option to list empty groups.
5. Exports detailed and summary CSV reports.
6. Count members by type (user mailbox, shared mailbox, contact, etc.).
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string]$GroupNamesFile,
    [switch]$IsEmpty,
    [int]$MinGroupMembersCount,
    [string]$UserName,
    [string]$Password,
    [Switch]$NoMFA
)

Function Get_Members {
    $DisplayName = $_.DisplayName
    Write-Progress -Activity "`nProcessed Group count: $Count `" -Status "Getting members of: $DisplayName"
    $Alias = $_.Alias
    $EmailAddress = $_.PrimarySmtpAddress
    $HiddenFromAddressList = $_.HiddenFromAddressListsEnabled
    $RecipientFilter = $_.RecipientFilter
    $RecipientHash = @{}
    for ($KeyIndex = 0; $KeyIndex -lt $RecipientTypeArray.Length; $KeyIndex += 2) {
        $key = $RecipientTypeArray[$KeyIndex]
        $Value = $RecipientTypeArray[$KeyIndex+1]
        $RecipientHash.Add($key,$Value)
    }
    $Manager = $_.ManagedBy
    if ($Manager -eq $null) { $Manager = "-" }
    $Recipient = ""
    $Members = Get-Recipient -ResultSize unlimited -RecipientPreviewFilter $RecipientFilter

    #GroupSize Filter
    if ([int]$MinGroupMembersCount -ne "" -and $Members.Count -lt [int]$MinGroupMembersCount) { $Print = 0 }
    #Empty Group Filter
    elseif ($Members.Count -eq 0) {
        $Member = "No Members"
        $RecipientTypeDetail = "-"
        Print_Output
    }
    else {
        foreach ($Member in $Members) {
            if ($IsEmpty.IsPresent) { $Print = 0; break }
            $RecipientTypeDetail = $Member.RecipientTypeDetails
            $MemberEmail = $Member.PrimarySMTPAddress
            foreach ($key in [object[]]$RecipientHash.Keys) {
                if (($RecipientTypeDetail -eq $key) -eq "true") { [int]$RecipientHash[$key] += 1 }
            }
            Print_Output
        }
    }

    #Export Summary Report
    if ($Print -eq 1) {
        $Hash = $RecipientHash.GetEnumerator() | Sort-Object -Property value -Descending | ForEach-Object {
            if ([int]$_.Value -gt 0) {
                if ($Recipient -ne "") { $Recipient += ";" }
                $Recipient += @("$($_.Key) - $($_.Value)")
            }
            if ($Recipient -eq "") { $Recipient = "-" }
        }
        $Output = @{
            'DisplayName' = $DisplayName
            'PrimarySmtpAddress' = $EmailAddress
            'Alias' = $Alias
            'Manager' = $Manager
            'GroupMembersCount' = $Members.Count
            'HiddenFromAddressList' = $HiddenFromAddressList
            'MembersCountByType' = $Recipient
        }
        New-Object PSObject -Property $Output |
            Select-Object DisplayName,PrimarySmtpAddress,Alias,Manager,HiddenFromAddressList,GroupMembersCount,MembersCountByType |
            Export-Csv -Path $ExportSummaryCSV -NoType -Append
    }
}

Function Print_Output {
    if ($Print -eq 1) {
        $Result = @{
            'DisplayName' = $DisplayName
            'PrimarySmtpAddress' = $EmailAddress
            'Alias' = $Alias
            'Manager' = $Manager
            'GroupMembersCount' = $Members.Count
            'Members' = $Member
            'MemberEmail' = $MemberEmail
            'MemberType' = $RecipientTypeDetail
        }
        New-Object PSObject -Property $Result |
            Select-Object DisplayName,PrimarySmtpAddress,Alias,Manager,GroupMembersCount,Members,MemberEmail,MemberType |
            Export-Csv -Path $ExportCSV -NoType -Append
    }
}

Function main {
    $RecipientTypeArray = Get-Content -Path .\RecipientTypeDetails.txt -ErrorAction Stop

    #Check for EXO v2 module
    if ((Get-Module ExchangeOnlineManagement -ListAvailable).Count -eq 0) {
        Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor Yellow
        $Confirm = Read-Host "Install Exchange Online module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") { Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force; Import-Module ExchangeOnlineManagement }
        else { Write-Host "EXO V2 module required. Exiting."; Exit }
    }

    #Check for MSOnline module
    if ((Get-Module MSOnline -ListAvailable).Count -eq 0) {
        Write-Host "MSOnline module is not available" -ForegroundColor Yellow
        $Confirm = Read-Host "Install MSOnline module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") { Install-Module MSOnline -Repository PSGallery -AllowClobber -Force; Import-Module MSOnline }
        else { Write-Host "MSOnline module required. Exiting."; Exit }
    }

    #Authentication
    if ($NoMFA.IsPresent) {
        if ($UserName -ne "" -and $Password -ne "") {
            $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
            $Credential = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
        } else { $Credential = Get-Credential -Credential $null }
        Write-Host "Connecting Azure AD..."
        Connect-MsolService -Credential $Credential | Out-Null
        Write-Host "Connecting Exchange Online PowerShell..."
        Connect-ExchangeOnline -Credential $Credential
    } else {
        Write-Host "Connecting Exchange Online PowerShell..."
        Connect-ExchangeOnline
        Write-Host "Connecting Azure AD..."
        Connect-MsolService | Out-Null
    }

    #Output file paths
    $ExportCSV = ".\DynamicDistributionGroup-DetailedMembersReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"
    $ExportSummaryCSV = ".\DynamicDistributionGroup-SummaryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt)).csv"

    $Count = 1

    #Process groups
    if ($GroupNamesFile -ne "") {
        $DDG = Import-Csv -Header "DisplayName" $GroupNamesFile
        foreach ($item in $DDG) {
            Get-DynamicDistributionGroup -Identity $item.displayname | ForEach-Object { $Print = 1; Get_Members }
            $Count++
        }
    } else {
        Get-DynamicDistributionGroup | ForEach-Object { $Print = 1; Get_Members; $Count++ }
    }

    #Open output files
    Write-Host "`nScript executed successfully"
    if (Test-Path $ExportCSV) {
        Write-Host "`nDetailed report available in:" -NoNewline -ForegroundColor Yellow
        Write-Host $ExportCSV
        Write-Host "Summary report available in:" -NoNewline -ForegroundColor Yellow
        Write-Host $ExportSummaryCSV
        Write-Host "`n~~ Script prepared by Ryan Adams ~~" -ForegroundColor Green
        Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "https://www.governmentcontrol.net/" -ForegroundColor Yellow -NoNewline; Write-Host " for auditing resources. ~~" -ForegroundColor Green
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        if ($UserInput -eq 6) { Invoke-Item $ExportCSV; Invoke-Item $ExportSummaryCSV }
    } else {
        Write-Host "No DynamicDistributionGroup found" -ForegroundColor Red
    }

    #Cleanup
    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
}

. main
