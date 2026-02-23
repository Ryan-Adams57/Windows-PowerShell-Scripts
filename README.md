# Introduction

This repository contains practical PowerShell scripts for managing Microsoft 365.

The scripts help administrators manage users, mailboxes, groups, calendars, and permissions across:

Exchange Online

SharePoint Online

Microsoft Teams

Microsoft Entra ID

Each script is self-contained and built for real-world tenant operations.

# What This Repository Covers

User lifecycle

Onboarding and offboarding automation

Login and MFA tasks

Mailbox management

Access control

Forwarding

Send on behalf

Mailbox type changes

Statistics and exports

Calendar management

Permission changes

Access audits

Event removal

Notifications

Groups and distribution lists

Membership reports

Security group exports

Group visibility

Email address updates

Connectivity and utilities

Exchange Online connection scripts

Maintenance and elevation tools

All scripts follow consistent naming.
Headers are clean.
Formatting is standardized.

# Key Features

Automates routine admin tasks

Reduces manual errors

Supports CSV export for reporting

Works with Task Scheduler

Uses clear parameters and inline help

Easy to modify

# How to Use

1. Set your execution policy if needed:

Set-ExecutionPolicy RemoteSigned

2. Install required modules (Exchange Online, Graph, etc.).

3. Connect with an account that has the right roles.

4. Test in a non-production tenant before running in production.

Each script includes parameters, examples, and error handling.

# Disclaimer

These scripts are provided “as is.”
Test before using them in production.
You are responsible for reviewing and approving changes.

# License

MIT License. See the LICENSE file for details.
