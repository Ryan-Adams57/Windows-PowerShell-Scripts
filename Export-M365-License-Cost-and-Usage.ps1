<#
=============================================================================================
Name         : Export Microsoft 365 License Cost & Usage Report Using PowerShell  
Version      : 1.1
website      : https://www.governmentcontrol.net/

-----------------
Script Highlights
-----------------
1. This script allows you to generate nicely formatted 2 CSV files of users’ license cost report and license usage & cost report in the organization.  
2. Helps to generate license cost report for inactive users.  
3. Results can be filtered to lists cost spent on never logged in users only.   
4. Exports disabled users’ license costs alone.  
5. Exports the cost of licenses for external users exclusively.  
6. Identify the Overlapping Licenses assigned to users. 
7. The script uses MS Graph PowerShell and installs MS Graph PowerShell SDK (if not installed already) upon your confirmation.  
8. The script can be executed with an MFA enabled account too.  
9. The script is scheduler-friendly.  
10. It can be executed with certificate-based authentication (CBA) too.  

For detailed Script execution:  https://blog.governmentcontrol.net/2024/06/12/export-microsoft-365-license-cost-report-using-powershell/
============================================================================================
#>

param (
    [string] $CertificateThumbprint,
    [string] $AppId,
    [string] $TenantId,
    [string] $UserCsvPath,
    [string] $Currency,
    [int] $InactiveDays,
    [switch] $NeverLoggedInUsersOnly,
    [switch] $ExternalUsersOnly,
    [switch] $EnabledUsersOnly,
    [switch] $DisabledUsersOnly,
    [switch] $LicenseOverlapingUsersOnly
)

#Function to check MgGraph module and connect to MgGraph.
function ConnectMgGraph{
    #Check MgGraph Beta Module and Install.
    $MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta -ListAvailable

    if($MsGraphBetaModule -eq $null)
    { 
        Write-Host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $Confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
        
        if($Confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph Beta module....."
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber 
            Write-host "Microsoft Graph Beta module is installed in the machine successfully." -ForegroundColor Magenta 
        } 
        
        else
        { 
            Write-Host "Exiting.`nNote: Microsoft Graph Beta module must be available in your system to run the script." -ForegroundColor Red
            Exit 
        } 
    }

    #Disconnect MgGraph if already connected.
    if( (Get-MgContext) -ne $null )
    {
        Disconnect-MgGraph | Out-Null
    }

    Write-Host Connecting to Microsoft Graph...

    #Connect to MgGraph via certificate.
    if (($CertificateThumbprint -ne "") -and ($AppId -ne "") -and ($TenantId -ne "")) 
    {
        Connect-MgGraph -TenantId $TenantId -AppId $AppId -CertificateThumbprint $CertificateThumbprint -NoWelcome
        if( (Get-MgContext) -ne $null )
        {
            Write-Host "Connected to Microsoft Graph PowerShell using "(Get-MgContext).AppName" Application Certificate." -ForegroundColor Green
        }
    }

    #Connect to MgGraph.
    else
    {
        Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All" -NoWelcome
        if( (Get-MgContext) -ne $null )
        {
            Write-Host "Connected to Microsoft Graph PowerShell using" (Get-MgContext).Account "account.`n" -ForegroundColor Green
        }
    }

    #Check connection error.
    if ( ($ConnectionError -ne $null) -or ((Get-MgContext) -eq $null) )
    {    
        Exit
    }
}

#Function for the license usage summary report .
function LicenceUsageReport
{
    Write-Host "Fetching Licenses....`n"
    $Count =0
    $TotalConsumedUnitsCost=0
    $TotalPurchasedUnitsCost=0
    $TotalUnusedUnitsCost=0

    #result path for Organization license report.
    $Location=Get-Location
    $Global:organizationLicenseResultPath= "$Location\LicenseUsageReport "+$DateTime+".csv"

    #Get all the license used by the organization.
    Get-MgBetaSubscribedSku | Select-Object  SkuId , ConsumedUnits , @{Name="PurchasedUnits"; Expression={$_.PrepaidUnits.Enabled} } |
    ForEach-Object {
        $Count++
        $SkuId = $_.'SkuId'
        $ProductDisplayName = $SkuIdDictionary.$SkuId[0]
        $Cost = $SkuIdDictionary.$SkuId[1]
        Write-Progress -Activity "Processing `"$ProductDisplayName`" Subscription " -Status "Processed Subscription Count: $Count"


        #Get cost of license which is unknown.   
        if($Cost -eq '_')
        {     
            Write-host "Enter The Cost for" -NoNewline
            Write-Host " $ProductDisplayName " -ForegroundColor Magenta -NoNewline
            write-Host "License :" -NoNewline
            $Cost = Read-Host  
            $SkuIdDictionary.$SkuId[1] = $Cost ;
        }

        #Calculation.
        $Cost = [decimal] $Cost   
        $UnusedUnits = ([int]$_.'PurchasedUnits'- [int]$_.'ConsumedUnits' )
        [decimal]$ConsumedUnitsCost =($_.'ConsumedUnits' * $Cost )
        [decimal]$PurchasedUnitsCost = ($_.'PurchasedUnits' * $Cost )
        [decimal]$UnusedUnitsCost = $UnusedUnits * $Cost
        [decimal]$TotalConsumedUnitsCost+=$ConsumedUnitsCost
        [decimal]$TotalPurchasedUnitsCost+=$PurchasedUnitsCost
        [decimal]$TotalUnusedUnitsCost+=$UnusedUnitsCost

        #Export into CSV file. 
        $OrganizationLicenseDetail = @{'License Name' = $ProductDisplayName;'Cost'=$Currency+$Cost;'Consumed Units'= $_.'ConsumedUnits'; 'Purchased Units'=$_.'PurchasedUnits' ; 'Unused Units'=$UnusedUnits ; 'Consumed Units Cost'=$Currency+$ConsumedUnitsCost;'Purchased Units Cost'=$Currency+$PurchasedUnitsCost ; 'Unused Units Cost'=$Currency+$UnusedUnitsCost ; 'SkuID'=$skuID}
        
        $OrganizationLicenseDetailObject = New-Object PSObject -Property $OrganizationLicenseDetail
        $OrganizationLicenseDetailObject | Select-object 'License Name','Cost','Purchased Units','Consumed Units','Unused Units','Purchased Units Cost','Consumed Units Cost','Unused Units Cost','SkuID' | Export-csv -path $Global:organizationLicenseResultPath  -NoType -Append -Force
    
    }
    #Add New Line to differentiate the total.
    $NewLine=""
    $NewLine | Add-Content -Path $Global:organizationLicenseResultPath

    #Export the total cost for the license.
    $OrganizationLicenseTotalCost = @{'License Name'="Total"; 'Cost'='-' ;'Purchased Units'= '-' ;'Consumed Units' = '-';'Unused Units' ='-';'Consumed Units Cost'= $Currency+$TotalConsumedUnitsCost;'Purchased Units Cost'=$Currency+$TotalPurchasedUnitsCost ;'Unused Units Cost'=$Currency+$TotalUnusedUnitsCost ; 'SkuID' = '-'}
    
    $OrganizationLicenseTotalCostObject = New-Object PSObject -Property $OrganizationLicenseTotalCost
    $OrganizationLicenseTotalCostObject| Select-object 'License Name','Cost','Purchased Units','Consumed Units','Unused Units','Purchased Units Cost','Consumed Units Cost','Unused Units Cost','SkuID' | Export-csv -path $Global:organizationLicenseResultPath  -NoType -Append -Force
    

}

#Funtion to process the data and export.
function LicensedUserExport
{
    param(
        [Array]  $AssignedLicenses,
        [string] $UserPrincipalName,
        [object] $User
    )

    $Global:UserLicenseResultPath= "$Location\UsersLicenseCostReport "+$DateTime+".csv"

    #SignInDateTime
    $LastSignInDateTime=if($User.SignInActivity.LastSignInDateTime)
                            {$User.SignInActivity.LastSignInDateTime}
                        else
                            {'-'}

    $UserNoInActiveDays=if($User.SignInActivity.LastSignInDateTime)
                            {(New-TimeSpan -Start $LastSignInDateTime).Days}
                        else
                            {"Never Logged In"}

    $LastSuccessfulSignInDateTime=if($User.SignInActivity.LastSuccessfulSignInDateTime)
                                        {$User.SignInActivity.LastSuccessfulSignInDateTime}
                                  else
                                        {'-'}

    if($InactiveDays)
    {
        if($UserNoInActiveDays -eq "Never Logged In" )
        {
            Return
        }

        elseif($InactiveDays -gt $UserNoInActiveDays)
        {
            Return
        }
    }

    elseif(($NeverLoggedInUsersOnly) -and ($UserNoInActiveDays -ne "Never Logged In" ))
    {
        Return
    }

    #UserType
    $
