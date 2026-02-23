# Windows-PowerShell-Scripts

A collection of PowerShell scripts designed to automate and simplify administration tasks in Microsoft 365 and Exchange Online environments.

This repository focuses on user lifecycle management, mailbox administration, calendar permissions, group management, reporting, and system maintenance.

# Overview

Managing Microsoft 365 through the admin portal can be time-consuming. These scripts provide reusable, standardized tools to help administrators:

Automate user onboarding and offboarding

Manage mailbox permissions and access

Control calendar permissions

Configure email forwarding

Export mailbox and group data

Manage distribution lists and Microsoft 365 Groups

Perform system-wide maintenance tasks

All scripts follow consistent naming conventions for clarity and maintainability.

# Requirements

Windows PowerShell 5.1+ or PowerShell 7+

Microsoft 365 administrative permissions

Exchange Online Management Module (EXO V3 recommended)

Azure AD / Entra ID connectivity where required

# Connecting to Exchange Online

Most scripts require an active Exchange Online session:

Install-Module ExchangeOnlineManagement
Connect-ExchangeOnline

Or run:

.\Install-Connect-EXO-V3.ps1

# Usage Example

.\Add_Calendar_Permissions.ps1

Each script runs independently and may prompt for required input.License

# License

This project is licensed under the MIT License. See the MIT LICENSE file for details.
