<#
=============================================================================================
Name:           Microsoft 365 Group Report
Description:    This script exports Microsoft 365 groups and their membership to CSV using Microsoft Graph PowerShell
Version:        3.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script uses Microsoft Graph PowerShell.
2. The script can be executed with certificate-based authentication (CBA) too.
3. Exports the report result to CSV. 
4. You can get members count based on Member Type such as User, Group, Contact, etc. 
5. The script is scheduler friendly.
6. Above all, the script exports output to nicely formatted 2 CSV files. One with group information and another with detailed group membership information. 

For detailed Script execution: https://www.governmentcontrol.net/
============================================================================================
#>

Param 
( 
    [Parameter(Mandatory = $false)] 
    [string]$GroupIDsFile,
    [switch]$DistributionList, 
    [switch]$Security, 
    [switch]$MailEnabledSecurity, 
    [Switch]$IsEmpty, 
    [Int]$MinGroupMembersCount,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
) 

Function Get_members
{
    $DisplayName=$_.DisplayName
    Write-Progress -Activity "`n     Processed Group count: $Count `n"  -Status "Getting members of: $DisplayName"
    $EmailAddress=$_.Mail
    if($_.GroupTypes -eq "Unified")
    {
        $GroupType="Microsoft 365"
    }
    elseif($_.Mail -ne $null)
    {
        if($_.SecurityEnabled -eq $false)
        {
            $GroupType="DistributionList"
        }
        else
        {
            $GroupType="MailEnabledSecurity"
        }
    }
    else
    {
        $GroupType="Security"
    }
    $GroupId=$_.Id
    $Recipient=""
    $RecipientHash=@{}
    for($KeyIndex = 0; $KeyIndex -lt $RecipientTypeArray.Length; $KeyIndex += 2)
    {
        $key=$RecipientTypeArray[$KeyIndex]
        $Value=$RecipientTypeArray[$KeyIndex+1]
        $RecipientHash.Add($key,$Value)
    }
    $Members=Get-MgGroupMember -All -GroupId $GroupId
    $MembersCount=$Members.Count
    $Members=$Members.AdditionalProperties

    if(($Security.IsPresent) -and ($GroupType -ne "Security")) { Return }
    if(($DistributionList.IsPresent) -and ($GroupType -ne "DistributionList")) { Return }
    if(($MailEnabledSecurity.IsPresent) -and ($GroupType -ne "MailEnabledSecurity")) { Return }

    if(([int]$MinGroupMembersCount -ne "") -and ($MembersCount -lt [int]$MinGroupMembersCount))
    {
        Return
    }
    elseif($MembersCount -eq 0)
    {
        $MemberName="No Members"
        $MemberEmail="-"
        $MemberType="-"
        Print_Output
    }
    else
    {
        foreach($Member in $Members){
            if($IsEmpty.IsPresent) { return }

            $MemberName=$Member.displayName
            if($Member.'@odata.type' -eq '#microsoft.graph.user') { $MemberType="User" }
            elseif($Member.'@odata.type' -eq '#microsoft.graph.group') { $MemberType="Group" }
            elseif($Member.'@odata.type' -eq '#microsoft.graph.orgContact') { $MemberType="Contact" }

            $MemberEmail=$Member.mail
            if($MemberEmail -eq "") { $MemberEmail="-" }

            foreach($key in [object[]]$Recipienthash.Keys){
                if(($MemberType -eq $key) -eq "true")
                {
                    [int]$RecipientHash[$key]+=1
                }
            }
            Print_Output
        }
    }
 
    $Hash=@{}
    $Hash=$RecipientHash.GetEnumerator() | Sort-Object -Property value -Descending |foreach{
        if([int]$($_.Value) -gt 0 )
        {
            if($Recipient -ne "") { $Recipient+=";" } 
            $Recipient+=@("$($_.Key) - $($_.Value)")    
        }
        if($Recipient -eq "") { $Recipient="-" }
    }

    $Result=@{
        'DisplayName'=$DisplayName;
        'EmailAddress'=$EmailAddress;
        'GroupType'=$GroupType;
        'GroupMembersCount'=$MembersCount;
        'MembersCountByType'=$Recipient
    }
    $Results= New-Object PSObject -Property $Result 
    $Results | Select-Object DisplayName,EmailAddress,GroupType,GroupMembersCount,MembersCountByType | Export-Csv -Path $ExportSummaryCSV -NoTypeInformation -Append
}

Function Print_Output
{
    $Result=@{
        'GroupName'=$DisplayName;
        'GroupEmailAddress'=$EmailAddress;
        'Member'=$MemberName;
        'MemberEmail'=$MemberEmail;
        'MemberType'=$MemberType
    } 
    $Results= New-Object PSObject -Property $Result 
    $Results | Select-Object GroupName,GroupEmailAddress,Member,MemberEmail,MemberType | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

Function CloseConnection
{
    Disconnect-MgGraph | Out-Null
    Exit
}

Function main() 
{
    $MsGraphModule =  Get-Module Microsoft.Graph -ListAvailable  
    if($MsGraphModule -eq $null)
    { 
        Write-host "Important: MicrosoftGraph module is unavailable. It is mandatory to have this module installed to run the script successfully." 
        $confirm= Read-Host "Are you sure you want to install module? [Y] Yes [N] No"  
        if($confirm -match "[yY]") 
        { 
            Write-host "`nInstalling MicrosoftGraph module..."
            Install-Module Microsoft.Graph -Repository PsGallery -Force -AllowClobber -Scope CurrentUser
            Write-host "`nRequired module installed successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. MicrosoftGraph module must be available to run the script." -ForegroundColor Red 
            Exit 
        } 
    } 

    Write-Host "`nConnecting to Microsoft Graph...`n"
    $Scopes = @("Directory.Read.All")  
    $Error.Clear()  

    if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
    {  
        try
        {
            Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint 
        }
        catch
        {
            Write-Host "`nPlease provide correct details!" -ForegroundColor Red
            Exit
        }
    }  
    else  
    {
        Connect-MgGraph -Scopes $Scopes
    } 

    Write-Host "`nMicrosoft Graph connected" -ForegroundColor Green

    $ExportCSV=".\M365Group-DetailedMembersReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
    $ExportSummaryCSV=".\M365Group-SummaryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

    $RecipientTypeArray=Get-Content -Path .\RecipientTypeDetails.txt -ErrorAction Stop
    $Count=0
    Write-Progress -Activity "Collecting group info"

    if([string]$GroupIDsFile -ne "") 
    { 
        $DG=Import-Csv -Header "DisplayName" $GroupIDsFile
        foreach($item in $DG){
            Get-MgGroup -GroupId $item.displayname | Foreach{
                $Count++
                Get_Members
            }
        }
    }
    else
    {
        Get-MgGroup -All -ErrorAction SilentlyContinue -ErrorVariable PermissionError| Foreach{
            $Count++
            Get_Members
        }
        if($PermissionError)
        {
            Write-Host "Please add required permissions!" -ForegroundColor Red
            CloseConnection
        }
    }

    Write-Host "`nScript executed successfully"

    if(Test-Path -Path $ExportCSV)
    {
        Write-Host "`nDetailed report available in:" -ForegroundColor Yellow
        Write-Host $ExportCSV 
        Write-host "`nSummary report available in:" -ForegroundColor Yellow
        Write-Host $ExportSummaryCSV 
        Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green

        $Prompt = New-Object -ComObject wscript.shell  
        $UserInput = $Prompt.popup("Do you want to open output file?",0,"Open Output File",4)  
        If ($UserInput -eq 6)  
        {  
            Invoke-Item "$ExportCSV"  
            Invoke-Item "$ExportSummaryCSV"
            CloseConnection
        } 
    }
    Else
    {
        Write-Host "`nNo group found" -ForegroundColor Red
        CloseConnection
    }
}

. main
