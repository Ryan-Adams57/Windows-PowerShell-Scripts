<#
=============================================================================================
Name:    Get SharePoint Files & Folders Created By External Users Using PowerShell
Version: 2.0
Author:  Ryan Adams
GitHub:  https://github.com/Ryan-Adams57
GitLab:  https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content

~~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~~
1. The script automatically verifies and installs the PnP module (if not installed already) upon your confirmation. 
2. Retrieves all files and folders created by external users for all sites. 
3. Gets files and folders created by external users on a specific site. 
4. Finds files and folders created by a specific external user. 
5. Allows to filter the data to display either files or folders created by external users. 
6. The script can be executed with an MFA-enabled account too. 
7. The script supports Certificate-based authentication (CBA) too. 
8. Exports the report results to a CSV file.

For detailed script execution: https://www.governmentcontrol.net/
~~~~~~~~~
Change Log:
~~~~~~~~~
  V1.0 (Jun 11, 2024) - File created
  V2.0 (Dec 29, 2025) - Handled ClientId requirement for SharePoint PnP PowerShell module and made minor usability changes

=============================================================================================
#>

param
( 
   [Parameter(Mandatory = $false)]
   [Switch] $FoldersOnly,
   [Switch] $FilesOnly,
   [string] $CreatedBy ,
   [String] $UserName,
   [String] $Password,
   [String] $ClientId,
   [String] $CertificateThumbprint,
   [String] $TenantName,  #(Example : If your tenant name is 'contoso.com', then enter 'contoso' as a tenant name )
   [String] $SiteAddress,    #(Enter the specific site URL that you want to retrieve the data from.)
   [String] $SitesCsv 
)

#Check for SharePoint PnPPowerShellOnline module availability
Function Installation-Module
{
 $Module = Get-InstalledModule -Name PnP.PowerShell -MinimumVersion 1.12.0 -ErrorAction SilentlyContinue
 If($Module -eq $null)
 {
  Write-Host SharePoint PnP PowerShell Module is not available -ForegroundColor Yellow
  $Confirm = Read-Host Are you sure you want to install module? [Yy] Yes [Nn] No
  If($Confirm -match "[yY]") 
  { 
   Write-Host "Installing PnP PowerShell module..."
   Install-Module PnP.PowerShell -Force -AllowClobber -Scope CurrentUser
   Import-Module -Name Pnp.Powershell        
  } 
  Else
  { 
   Write-Host "PnP PowerShell module is required to connect SharePoint Online.Please install module using 'Install-Module PnP.PowerShell' cmdlet." 
   Exit
  }
 }
 Write-Host `nConnecting to SharePoint Online...   
}


#SPO Site connection 
Function Connection-Module
{
 param
 (
  [Parameter(Mandatory = $true)]
  [String] $Url
 )
 if(($AdminName -ne "") -and ($Password -ne "") -and ($ClientId -ne ""))
 {
  $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
  $Credential  = New-Object System.Management.Automation.PSCredential $AdminName,$SecuredPassword
  Connect-PnPOnline -Url $Url -Credential $Credential -ClientId $ClientId
 }
 elseif($TenantName -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
 {
  Connect-PnPOnline -Url $Url -ClientId $ClientId -Thumbprint $CertificateThumbprint  -Tenant "$TenantName.onmicrosoft.com" 
 }
 else
 {
  Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId
 }
}


#Collecting the data and exporting it to a CSV file
$global:Count = 0
function Export_Data
{
    param
    (
        [Object] $ListItem,
        [Object] $ExternalUserIds,
        [String] $SiteUrl,
        [String] $SiteTitle
    ) 
    $AuthorFieldValue = $ListItem.FieldValues["Author"]
    $AuthorId = $AuthorFieldValue.LookupId
    $AuthorName = $AuthorFieldValue.LookupValue
    #Checking the resource created by an external user
    if(($ExternalUserIds | where{($_.Id -eq $AuthorId )}).count -eq 1)
    {
        $ExportResult =@{
            'File/Folder Name'  = $ListItem.FieldValues.FileLeafRef;
            'Relative URL' = $AdminUrl + $ListItem.FieldValues.FileRef;
            'Created On' = if ($ListItem.FieldValues.Created) {$ListItem.FieldValues.Created} else { "-" } ;
            'Created By' =  $AuthorName;
            'Resource Type' = $ListItem.FileSystemObjectType;
            'Site Name' = if ($SiteTitle) {$SiteTitle} else { "-" };
            'Site Url' =  $SiteUrl   
        }
        $ExportResult = New-Object PSObject -Property $ExportResult
        #Export result to csv
        $ExportResult | Select-Object 'Site Name','Site Url','File/Folder Name','Created By','Resource Type','Created On','Relative URL' | Export-Csv -path $OutputCSV -Append -NoTypeInformation
        $global:Count++
    } 
}
#Collecting items created by external users
function Get_ExternalUserItems
{
    param
    (
        [String] $ObjectType,
        [String] $SiteUrl
    ) 
    try 
    {
        $Web = Get-PnPWeb | Select Title
        if($CreatedBy -eq "")
        {
            #Geting external Users present in site
            $ExternalUserIds = Get-PnPUser | where{($_.IsShareByEmailGuestUser -eq "True" -or $_.IsHiddenInUI -eq "True" ) } | Select Id 
        }
        else
        {
            
            $ExternalUserIds = Get-PnPUser | where{($_.IsShareByEmailGuestUser -eq "True" -or $_.IsHiddenInUI -eq "True" ) -and ($_.Email -eq $CreatedBy -or ($_.LoginName -split {$_ -eq "|"})[2] -eq $CreatedBy) } | Select Id
        }
        if(($ExternalUserIds).count -gt 0)
        {
            Get-PnPList | Where-Object {$_.Hidden -eq $false -and $_.BaseType -eq "DocumentLibrary"} | ForEach-Object{
                if($ObjectType -eq "All"){
                    # Retrieves list items
                    Get-PnPListItem -List $_.Title -PageSize 2000 | ForEach-Object{
                        Export_Data -ListItem $_ -ExternalUserIds $ExternalUserIds -SiteUrl $SiteUrl -SiteTitle $Web.Title
                    }
                }
                else
                {
                    # Retrieves list items for a specific object type.
                    Get-PnPListItem -List $_.Title -PageSize 2000 | where { $_.FileSystemObjectType -eq $ObjectType} |ForEach-Object{
                        Export_Data -ListItem $_ -ExternalUserIds $ExternalUserIds -SiteUrl $SiteUrl -SiteTitle $Web.Title
                    }
                }   
                
            }
        }
    }
    catch
    {
        Write-Host "Error occured $($SiteUrl): $($_.Exception.Message)" -Foreground Yellow
    }
}

if($FoldersOnly.IsPresent)
{
    $ObjectType = "Folder"
}
elseif($FilesOnly.IsPresent)
{
    $ObjectType = "File"
}
else
{
  $ObjectType = "All"
}


Installation-Module
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OutputCSV = "$(Get-Location)\SPO_Files_&_Folders_Created_By_External_Users_$timestamp.csv"

if($TenantName -eq "" -and $SiteAddress -eq "" -and $SitesCsv -eq "")
{
 $TenantName = Read-Host "Enter your Tenant Name to Connect SharePoint Online  (Example : If your tenant name is 'contoso.com', then enter 'contoso' as a tenant name )  "
}

if($ClientId -eq "")
{
 $ClientId= Read-Host "ClientId is required to connect PnP PowerShell. Enter ClientId"
}

#To Retrive Data From All Sites Present In The Tenant
if($SiteAddress -ne "")
{
    Connection-Module -Url $SiteAddress 
    Get_ExternalUserItems -Objecttype $ObjectType -SiteUrl $SiteAddress
}
elseif($SitesCsv -ne "")
{
    try
    {
        Import-Csv -path $SitesCsv | ForEach-Object{
            Write-Progress -activity "Processing $($_.SitesUrl)" 
            Connection-Module -Url $_.SitesUrl 
            Get_ExternalUserItems -Objecttype $ObjectType -SiteUrl $_.SitesUrl
        }
    }
    catch
    {
        $_.Exception.Message
    }
}
