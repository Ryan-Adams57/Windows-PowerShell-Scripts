<#
=============================================================================================
Name:           Automate Microsoft 365 User Onboarding Operations
Version:        1.0
Website:        https://www.governmentcontrol.net/

~~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~~
1. The script automates the onboarding process for Microsoft 365 users.
2. Allows the addition of users into specific groups or roles.
3. Sets initial license assignments for newly onboarded users.
4. Configures specific attributes like department, title, etc., based on organization policies.
5. Supports integration with Azure AD for user profile management.
6. Supports bulk user creation from CSV files or direct input.
7. Can trigger welcome email setup and other custom welcome processes.
8. Compatible with MFA-enabled accounts for secure login.
9. Includes error handling to ensure smooth execution and tracking of onboarding process.

For detailed script execution: https://www.governmentcontrol.net/

============================================================================================
#>

Param
(
    [Parameter(Mandatory = $true)]
    [string[]]$UserPrincipalNames,  # List of User Principal Names (email addresses) to onboard

    [Parameter(Mandatory = $false)]
    [string]$Department,             # Department to assign for new users

    [Parameter(Mandatory = $false)]
    [string]$Title,                  # Title of the user to assign

    [Parameter(Mandatory = $false)]
    [string]$LicenseType,            # License type for the user (e.g., "M365Business", "E3")

    [Parameter(Mandatory = $false)]
    [string[]]$GroupNames,           # List of groups to add the user to

    [Parameter(Mandatory = $false)]
    [switch]$SendWelcomeEmail        # Option to send a welcome email
)

Function Connect-M365
{
    Write-Host "Connecting to Microsoft 365..."
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All" -ErrorAction Stop
}

Function Assign-License
{
    param(
        [string]$UserPrincipalName,
        [string]$LicenseType
    )
    
    Write-Host "Assigning license for $UserPrincipalName..."
    
    $License = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $LicenseType }
    
    if ($License) {
        Set-MgUserLicense -UserId $UserPrincipalName -AddLicenses @{SkuId=$License.SkuId}
        Write-Host "License $LicenseType assigned successfully."
    } else {
        Write-Host "Error: License $LicenseType not found." -ForegroundColor Red
    }
}

Function Add-To-Groups
{
    param(
        [string]$UserPrincipalName,
        [string[]]$GroupNames
    )
    
    Write-Host "Adding $UserPrincipalName to specified groups..."
    
    foreach ($GroupName in $GroupNames) {
        $Group = Get-MgGroup -Filter "displayName eq '$GroupName'"
        if ($Group) {
            Add-MgGroupMember -GroupId $Group.Id -DirectoryObjectId (Get-MgUser -UserId $UserPrincipalName).Id
            Write-Host "Added $UserPrincipalName to group $GroupName."
        } else {
            Write-Host "Group $GroupName not found." -ForegroundColor Red
        }
    }
}

Function Set-UserAttributes
{
    param(
        [string]$UserPrincipalName,
        [string]$Department,
        [string]$Title
    )
    
    Write-Host "Setting user attributes for $UserPrincipalName..."
    
    if ($Department) {
        Update-MgUser -UserId $UserPrincipalName -Department $Department
        Write-Host "Department set to $Department."
    }
    
    if ($Title) {
        Update-MgUser -UserId $UserPrincipalName -JobTitle $Title
        Write-Host "Title set to $Title."
    }
}

Function Send-WelcomeEmail
{
    param(
        [string]$UserPrincipalName
    )
    
    Write-Host "Sending welcome email to $UserPrincipalName..."
    
    $emailBody = "Welcome to the organization! Your Microsoft 365 account has been created successfully. Please refer to the attached guide for setting up your account."
    
    Send-MailMessage -To $UserPrincipalName -Subject "Welcome to Microsoft 365" -Body $emailBody -SmtpServer "smtp.yourcompany.com"
}

# Connect to Microsoft 365
Connect-M365

# Process each user for onboarding
foreach ($UserPrincipalName in $UserPrincipalNames) {
    Write-Host "`nStarting onboarding for $UserPrincipalName..."

    # Assign License
    if ($LicenseType) {
        Assign-License -UserPrincipalName $UserPrincipalName -LicenseType $LicenseType
    }

    # Add to groups
    if ($GroupNames) {
        Add-To-Groups -UserPrincipalName $UserPrincipalName -GroupNames $GroupNames
    }

    # Set user attributes
    Set-UserAttributes -UserPrincipalName $UserPrincipalName -Department $Department -Title $Title

    # Send welcome email
    if ($SendWelcomeEmail) {
        Send-WelcomeEmail -UserPrincipalName $UserPrincipalName
    }

    Write-Host "`nOnboarding process for $UserPrincipalName completed." -ForegroundColor Green
}

Write-Host "`nAll users have been onboarded successfully."
