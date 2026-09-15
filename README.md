# PortalVoIPBackupAgent

**Disaster-ready MySQL backups for VoIPSwitch — zero downtime, zero password hunting.**

[![Go](https://img.shields.io/badge/Go-1.20+-00ADD8?logo=go&logoColor=white)](#)
[![Windows](https://img.shields.io/badge/Windows_Server-2012%20R2%2B-0078D6?logo=windows&logoColor=white)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

PortalVoIPBackupAgent is a small, production-minded Windows tool that **finds VoIPSwitch MySQL settings automatically**, runs a safe `mysqldump`, zips the result, and can schedule itself for **01:00 daily** via Task Scheduler.

Built for operators who cannot afford a failed restore — and cannot afford a backup job that stops calls.

---

## Why this exists

On real VoIPSwitch hosts the database password is buried in XML configs (`voipswitch_config.xml`, `Database.config`, VoipBox…). Manual dumps get forgotten, scripts hardcode secrets, and a restore drill fails at the worst moment.

This agent:

- **Discovers** host, port, user, password, and database name from VoIPSwitch / VoipBox configs
- **Never prints** the password (only `pass_len`)
- **Does not stop** VoIPSwitch, MySQL, or Windows services
- **Does not modify** SIP/RTP/network settings or delete existing backups
- Installs a **daily 01:00** scheduled task as `SYSTEM`

---

## Features

| Capability | Detail |
|---|---|
| Auto-discovery | Scans common VoIPSwitch / VoipBox install paths |
| Safe dump flags | `--single-transaction --quick --routines --hex-blob` |
| Zip output | Timestamped `.zip` under `C:\ProgramData\VoipSwitchBackup\out` |
| Diagnose mode | Shows where credentials were found — without the secret |
| One-command install | Task Scheduler daily job |
| Companion script | Optional PowerShell path for labs / legacy hosts |

> Google Drive upload, AES encryption, VSS file copies, and retention policies are on the roadmap for the next release. This open release focuses on the rock-solid local dump + schedule core.

---

## Requirements

- Windows Server **2012 R2** or newer (also works on desktop Windows for labs)
- VoIPSwitch (or VoipBox) installed with a readable config
- `mysqldump.exe` available (typical path: `C:\MySQL\bin\mysqldump.exe`)
- Go **1.20+** only if you build from source

---

## Quick start

### 1) Build

```bat
scripts\build.cmd
```

Or:

```bat
set CGO_ENABLED=0
set GOOS=windows
set GOARCH=amd64
go build -ldflags="-s -w" -o PortalVoIPBackupAgent.exe .\cmd\PortalVoIPBackupAgent
```

### 2) Diagnose (no secrets printed)

```bat
PortalVoIPBackupAgent.exe diagnose
```

Example:

```text
OK source=C:\Program Files (x86)\VoipSwitch\...\voipswitch_config.xml
host=127.0.0.1 port=3306 user=root db=voipswitch pass_len=12
mysqldump=C:\MySQL\bin\mysqldump.exe
```

### 3) Run one backup

```bat
PortalVoIPBackupAgent.exe backup
```

Optional output folder:

```bat
PortalVoIPBackupAgent.exe backup C:\ProgramData\VoipSwitchBackup\out
```

### 4) Schedule every day at 01:00

```bat
PortalVoIPBackupAgent.exe install
```

Remove later with:

```bat
PortalVoIPBackupAgent.exe uninstall
```

---

## Commands

| Command | What it does |
|---|---|
| `diagnose` / `discover` | Locate MySQL settings; print host/user/db/`pass_len` only |
| `backup [outdir]` | Discover → `mysqldump` → zip |
| `install` | Create Task Scheduler job `VoipSwitchMySQLBackup` (daily 01:00, SYSTEM) |
| `uninstall` | Delete that scheduled task |
| `help` | Usage |

---

## Security model (read this)

- Credentials are **read from existing VoIPSwitch configs** at runtime — they are **not** stored in this repository.
- `diagnose` never prints the password.
- Do **not** commit `token.json`, OAuth client secrets, `.env`, private keys, or live SQL dumps.
- Prefer running the scheduled task as `SYSTEM` on a locked-down host.
- Treat backup zip files as **sensitive** (they contain your full CDR / routing DB). Encrypt and restrict ACLs on the output folder.

This repo ships **example paths only**. No customer passwords, Drive tokens, or production connection strings are included.

---

## Project layout

```text
cmd/PortalVoIPBackupAgent/   CLI entrypoint
internal/discover/           VoIPSwitch / VoipBox config discovery
internal/backup/             mysqldump + zip
scripts/build.cmd            Windows build helper
scripts/Backup-VoipSwitch.ps1  Optional PowerShell companion (sanitized)
```

---

## PowerShell companion

If you prefer a scriptable path for labs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Backup-VoipSwitch.ps1
```

Edit `$OutDir` / `$ShareDir` at the top of the script. It logs `pass_len` only.

---

## Restore sketch (operator checklist)

1. Install MySQL/MariaDB compatible with your VoIPSwitch version  
2. Create empty database  
3. `unzip` the backup and `mysql … < dump.sql`  
4. Point VoIPSwitch configs at the restored DB  
5. Validate licenses, dialplans, and a test call **before** cutover  

---

## Roadmap

- [ ] Credential Manager / DPAPI for optional overrides  
- [ ] AES-256-GCM archive encryption  
- [ ] Resumable **upload-only** Google Drive sync (no delete)  
- [ ] Local retention + free-space guard + single-flight lock  
- [ ] VSS copy of VoIPSwitch program/config trees  
- [ ] Machine-readable `manifest.json` + SHA-256 checksums  

---

## Author

**José Areche** — [joseareche.com](https://joseareche.com) · [GitHub @joseareche](https://github.com/joseareche)

VoIP, cloud telephony, and operator tooling with production criteria.

---

## License

MIT — see [LICENSE](LICENSE).