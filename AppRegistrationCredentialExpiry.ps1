<#
=============================================================================================
Name:           Retrieve Entra App Registrations with Expiring Secrets and Certificates
Description:    Retrieves the expiration details of Entra ID app registrations'
                client secrets and certificates and exports them to CSV.
Version:        1.0

Script Highlights:
1. Automatically verifies and installs the Microsoft Graph PowerShell SDK (if required).
2. Exports Entra ID apps with expiring client secrets and certificates to CSV.
3. Supports filtering by client secrets or certificates.
4. Allows filtering for soon-to-expire credentials (e.g., 30, 90 days).
5. Supports certificate-based authentication (CBA).
6. Scheduler-friendly.
============================================================================================
#>

Param
(
    [switch]$CreateSession,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [Switch]$ClientSecretsOnly,
    [Switch]$CertificatesOnly,
    [int]$SoonToExpireInDays
)

Function Connect_MgGraph
{
    # Check for module installation
    $Module = Get-Module -Name Microsoft.Graph.Beta -ListAvailable
    if ($Module.Count -eq 0) 
    { 
        Write-Host "Microsoft Graph PowerShell SDK is not available" -ForegroundColor Yellow  
        $Confirm = Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") 
        { 
            Write-Host "Installing Microsoft Graph PowerShell module..."
            Install-Module Microsoft.Graph.Beta -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
        }
        else
        {
            Write-Host "Microsoft Graph Beta PowerShell module is required to run this script."
            Exit
        }
    }

    if ($CreateSession.IsPresent)
    {
        Disconnect-MgGraph
    }

    Write-Host "Connecting to Microsoft Graph..."
    if (($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
    {  
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    }
    else
    {
        Connect-MgGraph -Scopes "Application.Read.All" -NoWelcome
    }
}

Connect_MgGraph

$Location = Get-Location
$ExportCSV = "$Location\AppRegistrations_Expiring_CertificatesAndSecrets_$((Get-Date -Format 'yyyy-MMM-dd-ddd hh-mm-ss tt')).csv"

$AppCount = 0
$PrintedCount = 0

$SwitchPresent = ($CertificatesOnly.IsPresent -or $ClientSecretsOnly.IsPresent -or ($SoonToExpireInDays -ne $null))

$RequiredProperties = @(
    'DisplayName','AppId','Id','KeyCredentials',
    'PasswordCredentials','CreatedDateTime','SignInAudience'
)

Get-MgBetaApplication -All -Property $RequiredProperties | ForEach-Object {

    $AppCount++
    $AppName = $_.DisplayName
    Write-Progress -Activity "Processed App Registration: $AppCount - $AppName"

    $AppId = $_.Id
    $Secrets = $_.PasswordCredentials
    $Certificates = $_.KeyCredentials
    $AppCreationDate = $_.CreatedDateTime

    $Owners = (Get-MgBetaApplicationOwner -ApplicationId $AppId).AdditionalProperties.userPrincipalName -join ","
    if (-not $Owners) { $Owners = "-" }

    # Client Secrets
    if (!($CertificatesOnly.IsPresent) -or (-not $SwitchPresent))
    {
        foreach ($Secret in $Secrets)
        {
            $ExpiryDays = (New-TimeSpan -Start (Get-Date).Date -End $Secret.EndDateTime).Days
            if ($ExpiryDays -lt 0) { continue }
            if (($SoonToExpireInDays) -and ($ExpiryDays -gt $SoonToExpireInDays)) { continue }

            $PrintedCount++
            [PSCustomObject]@{
                'App Name'              = $AppName
                'App Owners'            = $Owners
                'App Creation Time'     = $AppCreationDate
                'Credential Type'       = 'Client Secret'
                'Name'                  = $Secret.DisplayName
                'Id'                    = $Secret.KeyId
                'Creation Time'         = $Secret.StartDateTime
                'Expiry Date'           = $Secret.EndDateTime
                'Days to Expiry'        = $ExpiryDays
                'Friendly Expiry Date'  = "Expires in $ExpiryDays days"
                'App Id'                = $AppId
            } | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
        }
    }

    # Certificates
    if (!($ClientSecretsOnly.IsPresent) -or (-not $SwitchPresent))
    {
        foreach ($Certificate in $Certificates)
        {
            $ExpiryDays = (New-TimeSpan -Start (Get-Date).Date -End $Certificate.EndDateTime).Days
            if ($ExpiryDays -lt 0) { continue }
            if (($SoonToExpireInDays) -and ($ExpiryDays -gt $SoonToExpireInDays)) { continue }

            $PrintedCount++
            [PSCustomObject]@{
                'App Name'              = $AppName
                'App Owners'            = $Owners
                'App Creation Time'     = $AppCreationDate
                'Credential Type'       = 'Certificate'
                'Name'                  = $Certificate.DisplayName
                'Id'                    = $Certificate.KeyId
                'Creation Time'         = $Certificate.StartDateTime
                'Expiry Date'           = $Certificate.EndDateTime
                'Days to Expiry'        = $ExpiryDays
                'Friendly Expiry Date'  = "Expires in $ExpiryDays days"
                'App Id'                = $AppId
            } | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
        }
    }
}

if ($PrintedCount -eq 0)
{
    Write-Host "No data found for the given criteria."
}
else
{
    Write-Host "`nProcessed $AppCount app registrations."
    Write-Host "Output file contains $PrintedCount records."
    Write-Host "Output file location:" -ForegroundColor Yellow
    Write-Host $ExportCSV

    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.Popup("Do you want to open the output file?", 0, "Open Output File", 4)
    if ($UserInput -eq 6)
    {
        Invoke-Item $ExportCSV
    }
}
