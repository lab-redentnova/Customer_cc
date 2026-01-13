# Customer Complaint Automation Pipeline

## Overview

This repository implements an automated pipeline for processing customer complaints submitted via Google Forms.

**End-to-end flow**

Google Form
→ Google Sheet
→ Google Apps Script (on-submit trigger)
→ GitHub `repository_dispatch`
→ GitHub Actions (self-hosted Windows runner)
→ Python generates PDF (ReportLab)
→ PDF copied to Dropbox Team Shared Folder
→ CSV metadata updated and committed to repo
→ Optional email notification (SMTP)

The pipeline runs without cloud servers and uses a self-hosted GitHub Actions runner on a Windows machine with Dropbox Desktop installed.

---

## Why this setup

* No always-on cloud infrastructure
* No paid backend services
* Works with company Dropbox Team folders
* No Dropbox API, OAuth, or tokens
* Compatible with corporate Windows restrictions
* Designed for low-volume, business-critical workflows

---

## Architecture

* **Trigger**: Google Form submission
* **Event transport**: GitHub `repository_dispatch`
* **Execution**: Self-hosted GitHub Actions runner (Windows)
* **Processing**: Python (ReportLab PDF generation)
* **Storage**: Dropbox Desktop (Team Shared Folder)
* **Audit log**: `data/complaints_metadata.csv` updated and committed
* **Notifications**: SMTP email (toggleable)
* **Runner startup**: Windows Task Scheduler

---

## 1. Google Form & Google Sheet

1. Create a Google Form for customer complaints
2. Link responses to a Google Sheet
   (Responses tab → Link to Sheets)

---

## 2. Google Apps Script

1. In the linked Google Sheet:

   * Extensions → Apps Script
2. Paste the script from:

   ```
   apps_script/Code.gs
   ```
3. Set Script Property:

   * `GITHUB_PAT` (GitHub Personal Access Token)
4. Add an installable trigger:

   * Function: `onFormSubmit`
   * Event source: From spreadsheet
   * Event type: On form submit

This script sends a `repository_dispatch` event to GitHub on every form submission.

---

## 3. GitHub Workflow Trigger

The workflow is triggered using:

```yaml
on:
  repository_dispatch:
    types: [complaint_submitted]
```

The workflow file must exist on the repository’s default branch.

---

## 4. Self-Hosted GitHub Actions Runner

### Why self-hosted

GitHub-hosted runners cannot:

* Access Dropbox Desktop
* Access company file systems

This pipeline requires:

* A Windows self-hosted runner
* Dropbox Desktop installed and signed in
* Access to the Team Shared Folder

Runner labels used:

```
self-hosted, windows, dropbox
```

---

## 5. Runner Startup (Task Scheduler)

The Windows user account does not use a password or PIN, so the runner cannot be installed as a Windows service.

Instead, the runner is started using **Windows Task Scheduler**.

### Task Scheduler configuration

* Trigger: At user logon
* Run only when user is logged on
* Run with highest privileges
* Action:

  ```
  cmd.exe /c C:\actions-runner\run.cmd
  ```
* Start in:

  ```
  C:\actions-runner
  ```

This ensures the runner stays online even if PowerShell windows are closed.

---

## 6. Dropbox Integration

This pipeline does **not** use the Dropbox API.

* Dropbox Desktop syncs the Team Shared Folder locally
* PDFs are copied using filesystem operations
* Dropbox handles syncing automatically

Example target path:

```
C:\Users\User\Redent Dropbox\Redent Team Folder\Customer Complaints
```

The target folder path is configured through `DROPBOX_TARGET`.

---

## 7. Metadata CSV (Audit Log)

Each complaint submission appends/updates an audit record in:

```
data/complaints_metadata.csv
```

The workflow commits this file back to the repository so you always have a versioned log of:

* Submission timestamp / ID
* Customer / complaint identifiers included in payload
* Generated PDF filename
* GitHub run URL or run ID (if enabled)

If there are no changes in the CSV, the commit step is skipped.

---

## 8. Email Notifications (SMTP)

Email sending is supported via SMTP (for example SMTP2GO or any SMTP provider).

### Toggle behavior (no code changes)

Use GitHub Variables:

* `SEND_EMAIL`
* `SEND_TO_CUSTOMER`

Typical settings:

* Testing mode:

  * `SEND_EMAIL=false`
  * `SEND_TO_CUSTOMER=false`
* Production mode:

  * `SEND_EMAIL=true`
  * `SEND_TO_CUSTOMER=true`

### Required SMTP Secrets

Configured under:
`Settings → Secrets and variables → Actions`

* `SMTP_HOST`
* `SMTP_PORT`
* `SMTP_USER`
* `SMTP_PASS`
* `SMTP_FROM`

Optional (depending on your implementation):

* `SMTP_USE_SSL`
* `SMTP_USE_STARTTLS`
* `LAB_EMAIL`

---

## 9. GitHub Secrets and Variables

### Variables

* `DROPBOX_TARGET`
  Absolute local path to the Dropbox Team folder on the runner machine

* `SEND_EMAIL`
  `true` or `false`

* `SEND_TO_CUSTOMER`
  `true` or `false`

### Secrets

* `SMTP_HOST`
* `SMTP_PORT`
* `SMTP_USER`
* `SMTP_PASS`
* `SMTP_FROM`
* Optional: `SMTP_USE_SSL`, `SMTP_USE_STARTTLS`, `LAB_EMAIL`

---

## 10. Testing

1. Log into the runner machine
2. Ensure Dropbox Desktop is running
3. Verify runner status in GitHub (Idle)
4. Set variables for testing:

   * `SEND_EMAIL=false`
   * `SEND_TO_CUSTOMER=false`
5. Submit the Google Form
6. Confirm:

   * GitHub Actions run succeeds
   * PDF is generated in `out/*.pdf`
   * PDF appears in Dropbox Team folder
   * `data/complaints_metadata.csv` is updated/committed
   * No email is sent (in testing mode)

---

## Local Development (Optional)

1. Copy:

   * `.env.example` → `.env`
2. Fill required values
3. Run locally:

   * Windows:

     ```
     scripts/run_local.bat
     ```
   * Linux/macOS:

     ```
     scripts/run_local.sh
     ```

---

## Maintainer Notes

* The runner machine is part of the system
* Dropbox Desktop availability is critical
* Logging out stops the runner (Task Scheduler starts runner at logon)
* Keep Python and Git updated periodically
* If emails are enabled, validate SMTP credentials and sender policy
