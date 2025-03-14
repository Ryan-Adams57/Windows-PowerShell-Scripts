Connect to Office 365 (Exchange Online).

Before running any Office 365-related scripts, you need to connect to your Office 365 services.

For Exchange Online, use the following steps to establish a remote session.

# Install the Exchange Online Management module (if not already installed)
Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber

# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName your-admin@domain.com -ShowProgress $true

If you're using Microsoft 365 or Azure Active Directory, you'll use the MSOnline or AzureAD modules depending on what you're trying to report on:

# For Azure AD:
Install-Module -Name AzureAD
Connect-AzureAD -UserPrincipalName your-admin@domain.com

# Or, for MSOL (older):
Install-Module -Name MSOnline
Connect-MsolService
