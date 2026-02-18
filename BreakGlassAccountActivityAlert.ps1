<#
=============================================================================================

Name:           Break Glass Account Activity Alert Script  
Description:    Sends an automated email alert when activity is detected from break glass accounts.
Version:        1.0
Website:        https://www.governmentcontrol.net/

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Highlights:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Sends automated email alerts for break glass account activities with detailed information.
2. Exports activity reports in both CSV and HTML formats to the current working directory.
3. Supports monitoring of one or multiple break glass accounts.
4. Allows email notifications to be sent to one or more recipients.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Note:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Ensure the app registration used for certificate-based authentication has the following Application permissions:
Microsoft Graph: Application.Read.All, Mail.Send.Shared, User.Read.All  
Office 365 Exchange Online: Exchange.ManageAsApp   

For detailed script execution: https://github.com/Ryan-Adams57
=============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
    [Parameter(Mandatory = $True)]
    [string]$BGAccountUPNs,
    [Parameter(Mandatory = $True)]
    [string]$Recipients,
    [Switch]$HideSummaryAtEnd,
    [string]$FromAddress,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$AdminName,
    [string]$Password
)

Function Connect_Exo
{
 # Check for EXO module installation
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Exchange Online PowerShell module is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host EXO module is required to connect Exchange Online. Please install the module using the Install-Module ExchangeOnlineManagement cmdlet. 
   Exit
  }
 } 
 Write-Host Connecting to Exchange Online...
 # Storing credential in script for scheduling purpose / Passing credential as parameter
 if(($UserName -ne "") -and ($Password -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
 }
 elseif($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
 {
   Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ShowBanner:$false
 }
 else
 {
  Connect-ExchangeOnline -ShowBanner:$false
 }
}

Function Connect_ToMgGraph 
{
 # Check if Microsoft Graph module is installed
 $MsGraphModule = Get-Module Microsoft.Graph -ListAvailable
 if ($MsGraphModule -eq $null) 
 {
  Write-Host "`nImportant: Microsoft Graph module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
  $confirm = Read-Host "Are you sure you want to install Microsoft Graph module? [Y] Yes [N] No"
  if ($confirm -match "[yY]") 
  {
   Write-Host "Installing Microsoft Graph module..."
   Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber
   Write-Host "Microsoft Graph module is installed successfully" -ForegroundColor Magenta 
  } 
  else 
  {
   Write-Host "Exiting. `nNote: Microsoft Graph module must be available in your system to run the script." -ForegroundColor Red
   Exit
  }
 } 
 Write-Host "`nConnecting to Microsoft Graph..."

 # Connect using certificate-based authentication
 if (($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne "")) 
 {
  Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
 } 

 # Connect via interactive login
 else 
 {
  Connect-MgGraph -Scopes "Application.Read.All", "Mail.Send.Shared", "User.Read.All" -NoWelcome 
 }

 # Verify MS Graph session connection
 if ((Get-MgContext) -ne $null) 
 {
  if ((Get-MgContext).Account -ne $null) 
  {
   $Script:FromAddress= (Get-MgContext).Account
   Write-Host "Connected to Microsoft Graph PowerShell using account: $FromAddress"
  }
  else 
  {
   Write-Host "Connected to Microsoft Graph PowerShell using certificate-based authentication(CBA)."
   if (($Recipients -ne "") -and ([string]::IsNullOrEmpty($FromAddress))) 
   {
    Write-Host "`nError: FromAddress is required to send email when using CBA." -ForegroundColor Red
    Exit
   }
  }
 } 
 else 
 {
  Write-Host "Failed to connect to Microsoft Graph." -ForegroundColor Red
  Exit
 }
}

# Function to Send Email
Function SendEmail 
{
 # Recipients Address handling
 $EmailAddresses = ($Recipients -split ",").Trim()
 $ToRecipients = @()
 foreach ($Email in $EmailAddresses) {
  $ToRecipients += @{
   emailAddress = @{
    address = $Email
   }
  }
 }

 # Get the content from HTML report to place in email body
 $HtmlTable = Get-Content -Path $OutputHTML -Raw

 # Email body with table content
 $EmailBody = @"
 <html>
  <head>
    <meta charset='UTF-8'>
  </head>
  <body>
    <p>Hello Admin,</p>
    <p>Here is the break glass account(s) activity report for the period $StartDate to $EndDate.</p>

    $HtmlTable

    <p>If you notice any unusual activity or need to investigate a specific entry, please follow up via 
    <a href='https://purview.microsoft.com/audit/auditlogsearch' target='_blank'>Purview portal</a>.</p>  

    <p>Best regards,<br>IT Admin Team</p>
  </body>
 </html>
"@

 $params = @{
        Message = @{
            Subject = "Break glass account activity report"
            Body = @{
                ContentType = "HTML"
                Content     = $EmailBody
            }
            ToRecipients = $ToRecipients
        }
        SaveToSentItems = $true
    }
 Send-MgUserMail -UserId $Script:FromAddress -BodyParameter $params
}

Function HTML_Style
{
 # Start HTML with style and opening tags
 $Header = @"
 <html>
  <head>
    <meta charset="UTF-8">
    <style>
        table { width: 100%; border-collapse: collapse; font-family: Arial, sans-serif; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
  </head>
 <body>
  <h2>Break glass account activity report</h2>

  <table>
  <tr><th>Activity Time</th><th>Break Glass Account Name</th><th>Operation</th><th>Result</th><th>Workload</th><th>More Info</th></tr>
"@

 # Write the header once
 $Header | Out-File -FilePath $OutputHTML -Encoding UTF8
}

$MaxStartDate=((Get-Date).AddDays(-179)).Date

# Retrieve audit log for the past 180 days
if(($StartDate -eq $null) -and ($EndDate -eq $null))
{
 $EndDate=(Get-Date).Date
 $StartDate=$MaxStartDate
}
# Getting start date to audit export report
While($true)
{
 if ($StartDate -eq $null)
 {
  $StartDate=Read-Host Enter start time for report generation '(Eg:12/15/2023)'
 }
 Try
 {
  $Date=[DateTime]$StartDate
  if($Date -ge $MaxStartDate)
  { 
   break
  }
  else
  {
   Write-Host `nAudit can be retrieved only for the past 180 days. Please select a date after $MaxStartDate -ForegroundColor Red
   return
  }
 }
 Catch
 {
  Write-Host `nNot a valid date -ForegroundColor Red
 }
}

# Getting end date to export audit report
While($true)
{
 if ($EndDate -eq $null)
 {
  $EndDate=Read-Host Enter End time for report generation '(Eg: 12/15/2023)'
 }
 Try
 {
  $Date=[DateTime]$EndDate
  if($EndDate -lt ($StartDate))
  {
   Write-Host End time should be later than start time -ForegroundColor Red
   return
  }
  break
 }
 Catch
 {
  Write-Host `nNot a valid date -ForegroundColor Red
 }
}

$Location=Get-Location
$OutputCSV="$Location\BreakGlassAccountActivityReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 

$HTMLHeaderDefined="False"
$IntervalTimeInMinutes=1440    #$IntervalTimeInMinutes=Read-Host Enter interval time period '(in minutes)'
$CurrentStart=$StartDate
$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)

# Check whether CurrentEnd exceeds EndDate
if($CurrentEnd -gt $EndDate)
{
 $CurrentEnd=$EndDate
}

$CurrentResult= @()
$CurrentResultCount=0
$AggregateResultCount=0
Write-Host `nChecking for Break glass account activity from $StartDate to $EndDate... -ForegroundColor Yellow
$ProcessedRecords=0
$ExportResult=""   
$ExportResults=@()  

# Connect to PowerShell
Connect_Exo
Connect_ToMgGraph

# Validate breakglass account
$bgAccounts=$BGAccountUPNs -split ','
foreach($bgAccount in $bgAccounts)
{
 try
 {
  Get-MgUser -UserId $bgAccount -ErrorAction Stop
 }
 Catch
 {
  Write-Host $_.Exception.message -ForegroundColor Red
  Write-Host Break glass account $bgAccount not found. Check the name. -ForegroundColor Red
  Return
 }
}

# Start the activity monitoring loop
while($true)
{ 
 if($CurrentStart -eq $CurrentEnd)
 {
  Write-Host Start and end time are same. Please enter a different time range -ForegroundColor Red
  Exit
 }

 # Getting audit log for given time range
 $Results=Search-UnifiedAuditLog -StartDate $CurrentStart -EndDate $CurrentEnd -UserIds $BGAccountUPNs -SessionId s -SessionCommand ReturnLargeSet -ResultSize 5000
 $ResultCount=($Results | Measure-Object).count
 $AllAuditData=@()
 foreach($Result in $Results)
 {
  $ProcessedRecords++
  $MoreInfo=$Result.auditdata
  $AuditData=$Result.auditdata | ConvertFrom-Json
  $ActivityTime=Get-Date($AuditData.CreationTime) -format g
  $UserID=$AuditData.userId
  $Operation=$AuditData.Operation
  $ResultStatus=$AuditData.ResultStatus
  $Workload=$AuditData.Workload

  # Export result to csv
  $ExportResult=@{'Activity Time'=$ActivityTime;'Break Glass Account Name'=$UserID;'Operation'=$Operation;'Result'=$ResultStatus;'Workload'=$Workload;'More Info'=$MoreInfo}
  $ExportResults= New-Object PSObject -Property $ExportResult  
  $ExportResults | Select-Object 'Activity Time','Break Glass Account Name','Operation','Result','Workload','More Info' | Export-Csv -Path $OutputCSV -Notype -Append 
  
  if($HTMLHeaderDefined -eq "False")
  {
   $OutputHTML="$Location\BreakGlassAccountActivityReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).html" 
   HTML_Style
   $HTMLHeaderDefined="True"
  }

  # Export result to HTML
  $HTMLResult= "<tr><td>$($ActivityTime)</td><td>$($UserID)</td><td>$($Operation)</td><td>$($ResultStatus)</td><td>$($Workload)</td><td>$($MoreInfo)</td></tr>"
  $HTMLResult | Out-File -FilePath $OutputHTML -Append -Encoding UTF8 
 }
 Write-Progress -Activity "`n     Retrieving audit log from $CurrentStart to $CurrentEnd.."`n" Processed audit record count: $ProcessedRecords"
 $currentResultCount=$CurrentResultCount+$ResultCount
 if($CurrentResultCount -eq 50000)
 {
  Write-Host Retrieved max record for current range. Proceeding further may cause data loss or rerun the script with reduced time interval. -ForegroundColor Red
  $Confirm=Read-Host `nAre you sure you want to continue? [Y] Yes [N] No
  if($Confirm -match "[Y]")
  {
   $AggregateResultCount +=$CurrentResultCount
   Write-Host Proceeding audit log collection with data loss
   [DateTime]$CurrentStart=$CurrentEnd
   [DateTime]$CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)
   $CurrentResultCount=0
   $CurrentResult = @()
   if($CurrentEnd -gt $EndDate)
   {
    $CurrentEnd=$EndDate
   }
  }
  else
  {
   Write-Host Please rerun the script with reduced time interval -ForegroundColor Red
   Exit
  }
 }

 if($Results.count -lt 5000)
 {
  $AggregateResultCount +=$CurrentResultCount
  if($CurrentEnd -eq $EndDate)
  {
   break
  }
  $CurrentStart=$CurrentEnd 
  if($CurrentStart -gt (Get-Date))
  {
   break
  }
  $CurrentEnd=$CurrentStart.AddMinutes($IntervalTimeInMinutes)
  $CurrentResultCount=0
  $CurrentResult = @()
  if($CurrentEnd -gt $EndDate)
  {
   $CurrentEnd=$EndDate
  }
 }
 $ResultCount=0
}

if($HTMLHeaderDefined -eq "True") 
{
@"
</table>
</body>
</html>
"@ | Out-File -FilePath $OutputHTML -Append -Encoding UTF8
}

# Send report via email
if(($Recipients -ne "") -and ($AggregateResultCount -ne 0))
{
  SendEmail
}

Write-Host `n~~ Script prepared by Ryan Adams ~~`n -ForegroundColor Green
Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "GitHub - https://github.com/Ryan-Adams57" -ForegroundColor Yellow -NoNewline; Write-Host " ~~" -ForegroundColor Green `n

# Open output file after execution
if(!($HideSummaryAtEnd))
{
 If($AggregateResultCount -eq 0)
 {
  Write-Host No records found
 }
 else
 {
  Write-Host `nThe output file contains $AggregateResultCount audit records `n
  if((Test-Path -Path $OutputCSV) -eq "True") 
  {
   Write-Host `n "The Output file available in:" -ForegroundColor Yellow
    Write-Host CSV format: "$OutputCSV" `n 
    Write-Host HTML format: $OutputHTML
   $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",`   
 0,"Open Output File",4)   
   If ($UserInput -eq 6)   
   {   
    Invoke-Item "$OutputCSV" 
    Invoke-Item "$OutputHTML"  
   } 
  }
 }
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
# Disconnect MS Graph session
Disconnect-MgGraph | Out-Null
