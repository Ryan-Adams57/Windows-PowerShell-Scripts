<#
=============================================================================================
Name:           Microsoft Graph Certificate-Based App Registration Toolkit
Description:    Automates Azure AD app registration and certificate-based authentication setup
Version:        2.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content

Change Log
~~~~~~~~~~
 V1.0 - Initial release
 V2.0 - Code refinements and reliability improvements

============================================================================================
#>

param (
    $TenantID =$null,
    $ClientID = $null,
    $CertificateThumbprint = $null
) 

Function ConnectMgGraphModule
{
    $MsGraphModule =  Get-Module Microsoft.Graph -ListAvailable
    if($MsGraphModule -eq $null)
    { 
        Write-host "Microsoft Graph module is unavailable. This module must be installed to run the script." 
        $confirm = Read-Host "Install Microsoft Graph module? [Y] Yes [N] No"  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph module..."
            Install-Module Microsoft.Graph -Scope CurrentUser
            Write-host "Microsoft Graph module installed successfully." -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. Microsoft Graph module must be available to proceed." -ForegroundColor Red
            Exit 
        } 
    }
    Connect-MgGraph -Scopes "Application.ReadWrite.All,Directory.ReadWrite.All" -ErrorAction SilentlyContinue -Errorvariable ConnectionError | Out-Null
    if($ConnectionError -ne $null)
    {
        Write-Host "$ConnectionError" -Foregroundcolor Red
        Exit
    }
    Write-Host "Microsoft Graph PowerShell module connected successfully." -ForegroundColor Green
    $Script:TenantID = (Get-MgOrganization).Id
}

function RegisterApplication
{
    Write-Progress -Activity "Registering an application"
    while(1)
    {
        $Script:AppName = Read-Host "`nEnter a name for the new App"
        if($AppName -eq "")
        {
            Write-Host "App name cannot be empty." -ForegroundColor Red
            continue
        }
        break
    }
    $Script:RedirectURI = "https://login.microsoftonline.com/common/oauth2/nativeclient"
    $params = @{
        DisplayName = $AppName
        SignInAudience="AzureADMyOrg"
        PublicClient=@{
                RedirectUris = "$RedirectURI"
        }
        RequiredResourceAccess = @(
            @{
                ResourceAppId = "00000003-0000-0000-c000-000000000000"
                ResourceAccess = @(
                    @{
                        Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
                        Type = "Role"
                     }
                )
            }
        )
    }
    try{
        $Script:App = New-MgApplication -BodyParameter $params 
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
    }
    Write-Host "`nApp created successfully." -ForegroundColor Green
    $Script:APPObjectID = $App.Id
    $Script:APPID = $App.AppId
}

function CertificateCreation
{
    Write-Progress -Activity "Creating certificate"
    $Script:CertificateName = "$AppName-KeyCertificate"   
    $path = "Cert:\CurrentUser\My\"
    $Script:Subject = "CN=$CertificateName"
    try
    {
        $Script:Certificate = New-SelfSignedCertificate -Subject $Subject -CertStoreLocation $path -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -HashAlgorithm SHA256 
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
    }
    Write-Host "`nCertificate created successfully." -ForegroundColor Green
}

Function ImportCertificate
{
    Write-Progress -Activity "Importing certificate"
    $UploadCertificate = Read-Host "Enter certificate path (e.g., C:\Users\Admin\user.cer)"
    try
    {
        $Script:Certificate = Import-Certificate -FilePath "$UploadCertificate" -CertStoreLocation "Cert:\CurrentUser\My" 
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $ImportCertificateError = $True
        ShowAppDetails
        CloseConnection
    }
    Write-Host "`nCertificate imported successfully." -ForegroundColor Green
}

function UploadCertificate 
{
    Write-Progress -Activity "Uploading certificate"
    $KeyCredential = @{
        Type  = "AsymmetricX509Cert";
        Usage = "Verify";
        key   = $Certificate.RawData
    }
    Update-MgApplication -ApplicationId $APPObjectID -KeyCredentials $KeyCredential -ErrorAction SilentlyContinue -ErrorVariable ApplicationError
    if($ApplicationError -ne $null)
    {
        Write-Host "$ApplicationError" -ForegroundColor Red
        CloseConnection 
    }
    Write-Host "`nCertificate uploaded successfully." -ForegroundColor Green
    $Script:Thumbprint = $Certificate.Thumbprint
}

function SecureCertificate
{
    Write-Progress -Activity "Exporting PFX certificate" 
    $CertificateLocation = "$(Get-Location)\$CertificateName.pfx"
    $GetPassword = Read-Host "`nEnter password to secure certificate"
    try
    {
        $script:ExportError="False"
        $MyPwd = ConvertTo-SecureString -String "$GetPassword" -Force -AsPlainText
        Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$Thumbprint" -FilePath $CertificateLocation -Password $MyPwd | Out-Null
    }
    catch
    {
        $script:ExportError="True"
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    Write-Host "`nPFX file exported successfully." -ForegroundColor Green
    $Script:CertificateLocation = $CertificateLocation
}

function GrantPermission
{
    Write-Progress -Activity "Granting admin consent..."
    Start-Sleep -Seconds 20
    $Script:ClientID = $App.AppId
    $URL = "https://login.microsoftonline.com/$TenantID/adminconsent?client_id=$ClientID"
    Write-Host "`nAdmin consent is required. Please grant access to the application." -ForegroundColor Cyan
    Start-Process $URL
    Write-Host "After granting consent, return to this window to continue." -ForegroundColor Yellow
}

Function ShowAppDetails
{
    Write-Host "`nApplication Information:" -ForegroundColor Magenta
    $GetAppInfo = Get-MgApplication -All | Where-Object {$_.AppId -eq "$APPID"}
    $Owner = Get-MgApplicationOwner -ApplicationId $GetAppInfo.Id | Select-Object -ExpandProperty AdditionalProperties
    $AppInfo=[pscustomobject]@{
        'App Name'               = $GetAppInfo.DisplayName
        'Application (Client) Id'= $GetAppInfo.AppId
        'Object Id'              = $GetAppInfo.Id
        'Tenant Id'              = $TenantID
        'Certificate Thumbprint' = $Thumbprint
        'App Created Date Time'  = $GetAppInfo.CreatedDateTime
        'App Owner'              = (@($Owner.displayName)| Out-String).Trim()
    }
    $AppInfo | Format-List
}

Function RevokeCertificate
{
    Write-Progress -Activity "Revoking certificate"
    $NewKeys = @()
    $APPID = Read-Host "Enter Application (Client) ID to revoke certificate"
    $GetAppInfo = Get-MgApplication -All | Where-Object {$_.AppId -eq "$APPID"}
    if($GetAppInfo -ne $null)
    {
        $CertificateList = $GetAppInfo.KeyCredentials
        $KeyId=Read-Host "`nEnter certificate Key ID to revoke"
        foreach($List in $CertificateList)
        {
            if($List.KeyId -ne "$KeyId")
            {
                $NewKeys+=$List
            }
        }
        Update-MgApplication -ApplicationId $GetAppInfo.Id -KeyCredentials $NewKeys 
        Write-Host "`nCertificate revoked successfully." -ForegroundColor Green
    }
    else 
    {
        Write-Host "Application not found." -ForegroundColor Red
        CloseConnection
    }
}

Function ConnectApplication
{
    Write-Progress -Activity "Connecting to Microsoft Graph"
    try
    {
        Connect-MgGraph -TenantId $TenantID -ClientId $ClientID -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ApplicationConnectionError
        if($ApplicationConnectionError -ne $null)
        {
            Write-Host $ApplicationConnectionError -ForegroundColor Red
            Exit
        }
        Get-MgContext
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Exit
    }
}

function CloseConnection
{
   Disconnect-MgGraph | Out-Null 
   Exit
}

$ParameterPassed="False"
if($TenantID -ne $null -and $ClientID -ne $null -and $CertificateThumbprint -ne $null)
{
    $ParameterPassed="True"
    ConnectApplication
    Exit
}

Write-Host "`nAvailable operations:" -ForegroundColor Cyan
Write-Host " 1. Register app with new certificate"
Write-Host " 2. Register app with existing certificate"
Write-Host " 3. Revoke certificate"
Write-Host " 4. Connect using certificate"
$Action=Read-Host "`nChoose an action"

switch($Action){
   1 {
        ConnectMgGraphModule
        RegisterApplication
        CertificateCreation
        UploadCertificate
        SecureCertificate
        GrantPermission
        ShowAppDetails
        if($ExportError -ne "True")
        {
            Write-Host "`nPFX certificate available at $CertificateLocation" -ForegroundColor Green
        }
   }
   2 {
        ConnectMgGraphModule
        RegisterApplication
        ImportCertificate
        UploadCertificate
        GrantPermission
        ShowAppDetails
   }
   3 {
        ConnectMgGraphModule
        RevokeCertificate
   }
   4 {
        ConnectApplication
   }
   Default {
        Write-Host "No valid action selected." -ForegroundColor Red
   }
}

CloseConnection
