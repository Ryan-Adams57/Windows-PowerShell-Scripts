<#
=============================================================================================

Name:           Export Office 365 Mailbox Holds Report
Description:    This script exports hold enabled mailboxes to CSV
Version:        1.0
Website:        o365reports.com

Script Highlights: 
~~~~~~~~~~~~~~~~~
1.Generates 4 different mailbox holds reports.  
2.Automatically installs the Exchange Online module upon your confirmation when it is not available in your machine. 
3.Shows list of the mailboxes with all the active holds information for each mailbox. 
4.Shows the mailboxes with litigation hold enabled along with hold duration and other details. 
5.Displays in-place hold applied mailboxes. 
6.Lists mailboxes that are placed on retention hold and their retention policy. 
7.Supports both MFA and Non-MFA accounts.    
8.Exports the report in CSV format.  
9.Scheduler-friendly. You can automate the report generation upon passing credentials as parameters. 

For detailed Script execution: http://o365reports.com/2021/06/29/export-office-365-mailbox-holds-report-using-powershell
============================================================================================
#>

param (
    [string] $UserName = $null,
    [string] $Password = $null,
    [Switch] $LitigationHoldsOnly,
    [Switch] $InPlaceHoldsOnly,
    [Switch] $RetentionHoldsOnly
)

Function GetBasicData {
    $global:ExportedMailbox = $global:ExportedMailbox + 1
    $global:MailboxName = $_.Name 
    $global:RecipientTypeDetails = $_.RecipientTypeDetails
    $global:UPN = $_.UserPrincipalName
}
Function RetrieveAllHolds {
    if ($LitigationHoldsOnly.IsPresent) {
        $global:ExportCSVFileName = "LitigationHoldsReport" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv"
            Get-mailbox -IncludeInactiveMailbox -ResultSize Unlimited | Where-Object { $_.LitigationHoldEnabled -eq $True } | foreach-object {
            $CurrLitigationHold = $_
            GetLitigationHoldsReport
        }
    }
    elseif ($InPlaceHoldsOnly.IsPresent) {
        $global:ExportCSVFileName = "InPlaceHoldsReport" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv"
        Get-mailbox -IncludeInactiveMailbox -ResultSize Unlimited | Where-Object { $_.InPlaceHolds -ne $Empty } | foreach-object {
            $CurrInPlaceHold = $_
            GetInPlaceHoldsReport
        }
    }
    elseif ($RetentionHoldsOnly.IsPresent) {
        $global:ExportCSVFileName = "RetentionHoldsReport" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv"
        Get-mailbox -IncludeInactiveMailbox -ResultSize Unlimited | Where-Object { $_.RetentionHoldEnabled -eq $True } | foreach-object {
            $CurrRetentionHold = $_
            GetRetentionHoldsReport
        }
    }
    else {
        $global:ExportCSVFileName = "AllActiveHoldsReport" + ((Get-Date -format "MMM-dd hh-mm-ss tt").ToString()) + ".csv"
        Get-mailbox -IncludeInactiveMailbox -ResultSize Unlimited | Where-Object { $_.LitigationHoldEnabled -eq $True -or $_.RetentionHoldEnabled -eq $True -or $_.InPlaceHolds -ne $Empty -or $_.ComplianceTagHoldApplied -eq $True } | foreach-object {
            $CurrMailbox = $_
            GetDefaultReport
        }
    }
}

Function GetInPlaceHoldType($HoldGuidList) {
    $HoldTypes = @()
    $InPlaceHoldCount = 0
    $HoldGuidList | ForEach-Object {
        $InPlaceHoldCount = $InPlaceHoldCount + 1
        if ($_ -match "UniH") {
            $HoldTypes += "eDiscovery Case"
        }
        elseif ($_ -match "^mbx") {
            $HoldTypes += "Specific Location Retention Policy"
        }
        elseif ($_ -match "^\-mbx") {
            $HoldTypes += "Mailbox Excluded Retention Policy"
        }
        elseif ($_ -match "skp") {
            $HoldTypes += "Retention Policy on Skype"
        }
        else {
            $HoldTypes += "In-Place Hold"
        }
    }
    
    return ($HoldTypes -join ", "), $InPlaceHoldCount
}

Function GetLitigationHoldsReport {
    GetBasicData
    $LitigationOwner = $CurrLitigationHold.LitigationHoldOwner
    if ($null -ne $CurrLitigationHold.LitigationHoldDate) {
        $LitigationHoldDate = ($CurrLitigationHold.LitigationHoldDate).ToString().Split(" ") | Select-Object -Index 0
    }
    $LitigationDuration = $CurrLitigationHold.LitigationHoldDuration
    if ($LitigationDuration -ne "Unlimited") {
        $LitigationDuration = ($LitigationDuration).split(".") | Select-Object -Index 0
    }

    Write-Progress "Retrieving the Litigation Hold Information for the User: $global:MailboxName" "Processed Mailboxes Count: $global:ExportedMailbox" 

    #ExportResult
    $ExportResult = @{'Mailbox Name' = $global:MailboxName; 'Mailbox Type' = $global:RecipientTypeDetails; 'UPN' = $global:UPN; 'Litigation Owner' = $LitigationOwner; 'Litigation Duration' = $LitigationDuration; 'Litigation Hold Date' = $LitigationHoldDate }
    $ExportResults = New-Object PSObject -Property $ExportResult
    $ExportResults | Select-object 'Mailbox Name', 'UPN', 'Mailbox Type',  'Litigation Owner', 'Litigation Duration', 'Litigation Hold Date' | Export-csv -path $global:ExportCSVFileName -NoType -Append -Force  
}

Function GetInPlaceHoldsReport {
    GetBasicData
    $InPlaceHoldInfo = GetInPlaceHoldType ($CurrInPlaceHold.InPlaceHolds)
    $InPlaceHoldType = $InPlaceHoldInfo[0]
    $NumberOfHolds = $InPlaceHoldInfo[1]

    Write-Progress "Retrieving the In-Place Hold Information for the User: $global:MailboxName" "Processed Mailboxes Count: $global:ExportedMailbox"

    #Export Results
    $ExportResult = @{'Mailbox Name' = $global:MailboxName; 'Mailbox Type' = $global:RecipientTypeDetails; 'UPN' = $global:UPN; 'Configured InPlace Hold Count' = $NumberOfHolds; 'InPlace Hold Type' = $InPlaceHoldType }
    $ExportResults = New-Object PSObject -Property $ExportResult
    $ExportResults | Select-object 'Mailbox Name', 'UPN', 'Mailbox Type',  'Configured InPlace Hold Count', 'InPlace Hold Type' | Export-csv -path $global:ExportCSVFileName -NoType -Append -Force 
}

Function GetRetentionHoldsReport {
    GetBasicData
    $RetentionPolicy = $CurrRetentionHold.RetentionPolicy
    $RetentionPolicyTag = ((Get-RetentionPolicy -Identity $RetentionPolicy).RetentionPolicyTagLinks) -join ","

    if (($CurrRetentionHold.StartDateForRetentionHold) -ne $Empy) {
        $StartDateForRetentionHold = ($CurrRetentionHold.StartDateForRetentionHold).ToString().split(" ") | Select-Object -Index 0
    }
    else {
        $StartDateForRetentionHold = "-"
    }
    if (($CurrRetentionHold.EndDateForRetentionHold) -ne $Empy) {
        $EndDateForRetentionHold = ($CurrRetentionHold.EndDateForRetentionHold).ToString().split(" ") | Select-Object -Index 0
    }
    else {
        $EndDateForRetentionHold = "-"   
    }

    Write-Progress "Retrieving the Retention Hold Information for the User: $global:MailboxName" "Processed Mailboxes Count: $global:ExportedMailbox"

    #ExportResult
    $ExportResult = @{'Mailbox Name' = $global:MailboxName; 'Mailbox Type' = $global:RecipientTypeDetails; 'UPN' = $global:UPN; 'Retention Policy Name' = $RetentionPolicy; 'Start Date for Retention Hold' = $StartDateForRetentionHold; 'End Date for Retention Hold' = $EndDateForRetentionHold; 'Retention Policy Tag' = $RetentionPolicyTag }
    $ExportResults = New-Object PSObject -Property $ExportResult
    $ExportResults | Select-object 'Mailbox Name', 'UPN', 'Mailbox Type',  'Retention Policy Name', 'Start Date for Retention Hold', 'End Date for Retention Hold', 'Retention Policy Tag' | Export-csv -path $global:ExportCSVFileName -NoType -Append -Force 
}

Function GetDefaultReport {
    GetBasicData
    $LitigationHold = $CurrMailbox.LitigationHoldEnabled
    $ComplianceTag = $CurrMailbox.ComplianceTagHoldApplied
    $RetentionHold = $CurrMailbox.RetentionHoldEnabled
    $ArchiveStatus = $CurrMailbox.ArchiveStatus
    $RetentionPolicy = $CurrMailbox.RetentionPolicy
    
    $LitigationDuration = $
