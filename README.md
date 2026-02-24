# Windows PowerShell Scripts

A collection of PowerShell scripts to automate Microsoft 365, Exchange Online, Active Directory, and Windows system administration tasks.

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Microsoft 365 admin permissions
- Exchange Online Management Module (EXO V3)
- RSAT tools for AD-related scripts

## Connecting to Exchange Online

```powershell
Install-Module ExchangeOnlineManagement
Connect-ExchangeOnline
```

Or run `.\Install-Connect-EXO-V3.ps1`

## Categories

- **M365 & Exchange** — Onboarding, offboarding, mailbox management, permissions, forwarding
- **Calendar** — Add, change, and audit calendar permissions organization-wide
- **Distribution Lists & Groups** — List and export DL, O365, and AD security group members
- **Active Directory** — User logon reports, account expiration, computer management
- **System Administration** — Software inventory, OS info, Windows keys, maintenance
- **Network & Security** — IP config, BitLocker, certificates, audit reports
- **Imaging & Deployment** — DISM, drivers, printers, Office 365, dental software
- **File Management** — Sort files and images by type or date

## Usage

Each script runs independently and may prompt for input. Run from an elevated PowerShell session:

```powershell
.\ScriptName.ps1
```

## License

Licensed under the MIT License. See [MIT LICENSE](MIT%20LICENSE) for details.

# Disclaimer

Each script is provided as-is. Although these scripts have been tested in a production environment with working results, it is highly recommended to test them in your own environment at your own risk before deploying.
