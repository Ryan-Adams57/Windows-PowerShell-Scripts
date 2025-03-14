# Install the Exchange Online Management module (if not already installed)
Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber

# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName your-admin@domain.com -ShowProgress $true
