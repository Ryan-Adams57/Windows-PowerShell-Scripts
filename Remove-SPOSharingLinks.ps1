<#
=============================================================================================
Name:           Remove SharePoint Online Sharing Links
Version:        1.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/

Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Generates a report to preview SharePoint links before removal.
2. Removes file & folder sharing links based on 20+ filtering criteria.
3. Supports Anonymous, Organization, and Specific People links.
4. Allows revoking active, expired, never-expiring, or soon-to-expire links.
5. Targets specific SharePoint sites for scoped cleanup.
6. Automatically installs required PnP PowerShell module if missing.
7. Supports certificate-based login, MFA, and non-MFA accounts.
8. Scheduler-friendly for automated audits and link cleanup.

GitHub:  https://github.com/Ryan-Adams57
Gitlab:  https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content
=============================================================================================
#>

Param(
    [Parameter(Mandatory = $false)]
    [string]$AdminName,
    [string]$Password,
    [String]$ClientId,
    [String]$CertificateThumbprint,
    [string]$TenantName,
    [string]$ImportCsv,
    [Switch]$ActiveLinks,
    [Switch]$ExpiredLinks,
    [Switch]$LinksWithExpiration,
    [Switch]$NeverExpiresLinks,
    [int]$SoonToExpireInDays,
    [Switch]$GetAnyoneLinks,
    [Switch]$GetCompanyLinks,
    [Switch]$GetSpecificPeopleLinks,
    [Switch]$RemoveSharingLinks
)

#========================================================================================
# Function: Check and install PnP PowerShell module
#========================================================================================
Function Installation-Module {
    $Module = Get-InstalledModule -Name PnP.PowerShell -MinimumVersion 1.12.0 -ErrorAction SilentlyContinue
    If (-not $Module) {
        Write-Host "PnP PowerShell module is not available." -ForegroundColor Yellow
        $Confirm = Read-Host "Install module now? [Y] Yes [N] No"
        If ($Confirm -match "[yY]") {
            Write-Host "Installing PnP PowerShell module..."
            Install-Module PnP.PowerShell -Force -AllowClobber -Scope CurrentUser
            Import-Module PnP.PowerShell
        } Else {
            Write-Host "PnP PowerShell module is required. Exiting." -ForegroundColor Red
            Exit
        }
    }
    Write-Host "`nConnecting to SharePoint Online..."
}

#========================================================================================
# Function: Connect to SharePoint Online site
#========================================================================================
Function Connection-Module {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Url
    )
    If ($AdminName -and $Password -and $ClientId) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $AdminName, $SecuredPassword
        Connect-PnPOnline -Url $Url -Credential $Credential -ClientId $ClientId
    }
    ElseIf ($TenantName -and $ClientId -and $CertificateThumbprint) {
        Connect-PnPOnline -Url $Url -ClientId $ClientId -Thumbprint $CertificateThumbprint -Tenant "$TenantName.onmicrosoft.com"
    }
    Else {
        Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId
    }
}

#========================================================================================
# Function: Retrieve and optionally remove sharing links
#========================================================================================
Function Get-SharedLinks {
    $ExcludedLists = @("Form Templates","Style Library","Site Assets","Site Pages","Preservation Hold Library","Pages","Images","Site Collection Documents","Site Collection Images")
    $DocumentLibraries = Get-PnPList | Where-Object { $_.Hidden -eq $False -and $_.Title -notin $ExcludedLists -and $_.BaseType -eq "DocumentLibrary" }
    
    ForEach ($List in $DocumentLibraries) {
        $ListItems = Get-PnPListItem -List $List -PageSize 2000
        ForEach ($Item in $ListItems) {
            $FileName = $Item.FieldValues.FileLeafRef
            $ObjectType = $Item.FileSystemObjectType
            Write-Progress -Activity ("Site Name: $Site") -Status ("Processing Item: $FileName")
            $HasUniquePermissions = Get-PnPProperty -ClientObject $Item -Property HasUniqueRoleAssignments

            If ($HasUniquePermissions) {
                $FileUrl = $Item.FieldValues.FileRef
                If ($ObjectType -eq "File") { $FileSharingLinks = Get-PnPFileSharingLink -Identity $FileUrl }
                ElseIf ($ObjectType -eq "Folder") { $FileSharingLinks = Get-PnPFolderSharingLink -Folder $FileUrl }
                Else { continue }

                ForEach ($FileSharingLink in $FileSharingLinks) {
                    $Link = $FileSharingLink.Link
                    $Scope = $Link.Scope

                    # Filter by link type
                    If ($GetAnyoneLinks.IsPresent -and ($Scope -ne "Anonymous")) { Continue }
                    ElseIf ($GetCompanyLinks.IsPresent -and ($Scope -ne "Organization")) { Continue }
                    ElseIf ($GetSpecificPeopleLinks.IsPresent -and ($Scope -ne "Users")) { Continue }

                    $Permission = $Link.Type
                    $SharedLink = $Link.WebUrl
                    $FileSharingId = $FileSharingLink.Id
                    $PasswordProtected = $FileSharingLink.HasPassword
                    $BlockDownload = $Link.PreventsDownload
                    $RoleList = $FileSharingLink.Roles -join ","
                    $Users = $FileSharingLink.GrantedToIdentitiesV2.User.Email
                    $DirectUsers = $Users -join ","
                    $CurrentDateTime = (Get-Date).Date

                    If ($FileSharingLink.ExpirationDateTime) {
                        $ExpiryDate = [DateTime]$FileSharingLink.ExpirationDateTime
                        $ExpiryDays = (New-TimeSpan -Start $CurrentDateTime -End $ExpiryDate).Days
                        If ($ExpiryDate -lt $CurrentDateTime) {
                            $LinkStatus = "Expired"
                            $FriendlyExpiryTime = "Expired $($ExpiryDays * -1) days ago"
                        } Else {
                            $LinkStatus = "Active"
                            $FriendlyExpiryTime = "Expires in $ExpiryDays days"
                        }
                    } Else {
                        $LinkStatus = "Active"
                        $ExpiryDays = "-"
                        $ExpiryDate = "-"
                        $FriendlyExpiryTime = "Never Expires"
                    }

                    # Apply filters
                    If ($ActiveLinks.IsPresent -and $LinkStatus -ne "Active") { Continue }
                    ElseIf ($ExpiredLinks.IsPresent -and $LinkStatus -ne "Expired") { Continue }
                    ElseIf ($LinksWithExpiration.IsPresent -and -not $FileSharingLink.ExpirationDateTime) { Continue }
                    ElseIf ($NeverExpiresLinks.IsPresent -and $FriendlyExpiryTime -ne "Never Expires") { Continue }
                    ElseIf ($SoonToExpireInDays -ne "" -and (-not $FileSharingLink.ExpirationDateTime -or $SoonToExpireInDays -lt $ExpiryDays -or $ExpiryDays -lt 0)) { Continue }

                    # Remove sharing link if requested
                    If ($RemoveSharingLinks.IsPresent) {
                        Try {
                            If ($ObjectType -eq "File") { Remove-PnPFileSharingLink -FileUrl $FileUrl -Identity $FileSharingId -Force }
                            ElseIf ($ObjectType -eq "Folder") { Remove-PnPFolderSharingLink -Folder $FileUrl -Identity $FileSharingId -Force }
                            $LinkRemovalStatus = "Success"
                        } Catch {
                            Write-Host $_.Exception.Message -ForegroundColor Red
                            $LinkRemovalStatus = "Error occurred"
                        }
                    } Else { $LinkRemovalStatus = "No action performed" }

                    $Results = [PSCustomObject]@{
                        "Site Name"             = $Site
                        "Library"               = $List.Title
                        "Object Type"           = $ObjectType
                        "File/Folder Name"      = $FileName
                        "File/Folder URL"       = $FileUrl
                        "Link Type"             = $Scope
                        "Access Type"           = $Permission
                        "Roles"                 = $RoleList
                        "Users"                 = $DirectUsers
                        "File Type"             = $Item.FieldValues.File_x0020_Type
                        "Link Status"           = $LinkStatus
                        "Link Expiry Date"      = $ExpiryDate
                        "Days Since/To Expiry"  = $ExpiryDays
                        "Friendly Expiry Time"  = $FriendlyExpiryTime
                        "Password Protected"    = $PasswordProtected
                        "Block Download"        = $BlockDownload
                        "Shared Link"           = $SharedLink
                        "Link Removal Status"   = $LinkRemovalStatus
                    }

                    $Results | Export-Csv -Path $ReportOutput -NoTypeInformation -Append -Force
                    $Global:ItemCount++
                }
            }
        }
    }
}

#========================================================================================
# MAIN SCRIPT EXECUTION
#========================================================================================
$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportOutput = "$PSScriptRoot\SPO_SharingLinks_Report_$TimeStamp.csv"
$Global:ItemCount = 0

If (-not $ClientId) { $ClientId = Read-Host "ClientId is required to connect PnP PowerShell. Enter ClientId" }
If (-not $TenantName) { $TenantName = Read-Host "Enter your tenant name (e.g., 'contoso' for 'contoso.onmicrosoft.com')" }

# Install module if needed
Installation-Module

# Process CSV input
If ($ImportCsv) {
    $SiteCollections = Import-Csv -Path $ImportCsv
    ForEach ($Site in $SiteCollections) {
        $SiteUrl = $Site.SiteUrl
        Connection-Module -Url $SiteUrl
        $Site = (Get-PnPWeb | Select-Object -ExpandProperty Title)
        Get-SharedLinks
        Disconnect-PnPOnline -WarningAction SilentlyContinue
    }
} Else {
    # Process all sites
    Connection-Module -Url "https://$TenantName-admin.sharepoint.com"
    $SiteCollections = Get-PnPTenantSite | Where-Object { $_.Template -notin @("SRCHCEN#0","REDIRECTSITE#0","SPSMSITEHOST#0","APPCATALOG#0","POINTPUBLISHINGHUB#0","EDISC#0","STS#-1") }
    Disconnect-PnPOnline -WarningAction SilentlyContinue

    ForEach ($Site in $SiteCollections) {
        $SiteUrl = $Site.Url
        Connection-Module -Url $SiteUrl
        $Site = (Get-PnPWeb | Select-Object -ExpandProperty Title)
        Get-SharedLinks
    }
    Disconnect-PnPOnline -WarningAction SilentlyContinue
}

Write-Host "`n~~ Script prepared by Ryan Adams ~~`n" -ForegroundColor Green
Write-Host "GitHub: https://github.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Gitlab: https://gitlab.com/Ryan-Adams57" -ForegroundColor Cyan
Write-Host "Website: https://www.governmentcontrol.net/" -ForegroundColor Cyan
Write-Host "PasteBin: https://pastebin.com/u/Removed_Content" -ForegroundColor Cyan

# Output summary
If (Test-Path $ReportOutput) {
    Write-Host "`nThe output file contains $Global:ItemCount sharing links."
    Write-Host "The Output file is available at: $ReportOutput" -ForegroundColor Yellow
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open the output file?", 0, "Open Output File", 4)
    If ($UserInput -eq 6) { Invoke-Item $ReportOutput }
} Else {
    Write-Host "No records found." -ForegroundColor Yellow
}
