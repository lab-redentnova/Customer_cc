# Customer Complaint Automation Pipeline

Automates the processing of **Google Forms customer complaints** by generating a branded PDF report, optionally emailing it, and writing an audit trail of each complaint for downstream systems.

## Overview

**End-to-end flow**

Google Form → Google Sheet → Google Apps Script trigger → GitHub `repository_dispatch` → GitHub Actions (self-hosted runner) → Python pipeline

The Python pipeline:
- Generates a PDF (ReportLab) into `out/`
- sends email via SMTP
- Appends metadata to:
  - `data/complaints_metadata.csv` (versioned audit log)
  - `data/complaints_metadata.db` (SQLite, for real-time querying / use by other projects)

## Repository layout

- **`app/main.py`**: Orchestrates the pipeline (parse payload → generate PDF → email → metadata)
- **`app/payload.py`**: Parses the GitHub event payload into a normalized `Submission`
- **`app/pdf_report.py`**: PDF generation (dynamic section/row layout + a legacy fallback renderer)
- **`app/mailer.py`**: SMTP email sending
- **`app/metadata.py`**: Writes the audit record (CSV + SQLite)
- **`app/db_metadata.py`**: SQLite schema + insert helper
- **`apps_script/Code.gs`**: Google Apps Script that sends `repository_dispatch` to GitHub
- **`data/`**: Audit logs (`complaints_metadata.csv`, `complaints_metadata.db`)
- **`scripts/`**: Local run helpers + Windows runner helper
- **`logo.png`**: Used in the PDF header

## How the payload works

The pipeline is designed to be resilient to Google Form changes.
- The Apps Script builds a **sections/rows** structure dynamically from the current form (see `apps_script/Code.gs`).
- The Python side renders those sections directly into the PDF (see `app/pdf_report.py`).

Expected GitHub event shape (simplified):
- `event.client_payload.submission_id`
- `event.client_payload.complaint_id`
- `event.client_payload.submission_timestamp`
- `event.client_payload.email_to`
- `event.client_payload.sections` (preferred)

## Running locally (developer workflow)

This repo runs from the GitHub Actions event payload file (`GITHUB_EVENT_PATH`). To run locally, you typically create a local JSON event file and point `GITHUB_EVENT_PATH` at it.

**Windows (PowerShell / cmd):**

```
set GITHUB_EVENT_PATH=sample_event.json
scripts\run_local.bat
```

**Linux/macOS:**

```
export GITHUB_EVENT_PATH=sample_event.json
scripts/run_local.sh
```

Output:
- PDF: `out/<complaint_id>.pdf`
- CSV log: `data/complaints_metadata.csv`
- SQLite DB: `data/complaints_metadata.db`

## Configuration (environment variables)

### Email toggles
- **`SEND_EMAIL`**: `true` / `false` (default: `true`)
- **`SEND_TO_CUSTOMER`**: `true` / `false` (default: `true`)

### SMTP settings (required only if `SEND_EMAIL=true`)
> Note: in code, the password variable name is **`SMTP_PASSWORD`** (not `SMTP_PASS`).

- **`SMTP_HOST`**
- **`SMTP_PORT`** (default: `587`)
- **`SMTP_USER`**
- **`SMTP_PASSWORD`**
- **`SMTP_FROM`** (falls back to `SMTP_USER` if omitted)
- **`SMTP_USE_SSL`**: `true` / `false` (default: `false`)
- **`SMTP_USE_STARTTLS`**: `true` / `false` (default: `true`)
- **`LAB_EMAIL`**: comma-separated list used by the pipeline (and also used in `app/payload.py` as a fallback)

### PDF branding
- **`DOC_VERSION`**: footer text (default: `ReDent Nova GmbH • Customer Complaint Form`)
- **`MAIL_SUBJECT`**, **`MAIL_BODY`**: optional email subject/body overrides

## Metadata storage

Each run writes an audit record containing IDs, timestamps, email/dropbox status flags, links, and a JSON blob of all raw fields.

- **CSV**: `data/complaints_metadata.csv`
- **SQLite**: `data/complaints_metadata.db`, table **`complaints_metadata`**

### Querying the SQLite DB (example)

```
sqlite3 data/complaints_metadata.db "SELECT complaint_id, created_at_utc, customer_email FROM complaints_metadata ORDER BY id DESC LIMIT 5;"
```

## Google Apps Script setup

See **`apps_script/SETUP.md`** for the exact steps.

At a high level:
- Paste `apps_script/Code.gs` into the linked Google Sheet’s Apps Script project
- Add Script Properties:
  - `GITHUB_PAT`
  - `REPO_OWNER`
  - `REPO_NAME`
- Create an installable trigger for `onFormSubmit`

## Notes / current limitations

- **Dropbox upload**: `app/main.py` calls `upload_pdf_to_dropbox(...)`, but this repository does not currently include its implementation. If your deployment depends on Dropbox uploads, add an implementation module/function or wire in the missing dependency (see `TODOS.md`).

## Troubleshooting

- **“GITHUB_EVENT_PATH is missing…”**: set `GITHUB_EVENT_PATH` to a real event JSON file path.
- **Email fails but pipeline continues**: email is intentionally non-blocking; check SMTP env vars and credentials.
- **Complaint ID increments**: `app/id_generator.py` currently uses `data/complaints_metadata.csv` to determine the next sequence for the year.
