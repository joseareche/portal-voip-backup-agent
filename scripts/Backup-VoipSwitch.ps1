<#
.SYNOPSIS
  Companion backup script for VoIPSwitch MySQL (read-only discovery + mysqldump).
.NOTES
  Does not print passwords. Configure OUT_DIR / optional SHARE_DIR below.
#>
$ErrorActionPreference = "Stop"
$OutDir   = "C:\ProgramData\VoipSwitchBackup\out"
$LogDir   = "C:\ProgramData\VoipSwitchBackup\logs"
$ShareDir = ""   # optional, e.g. "D:\VoIPSwitchBackups" — leave empty to skip
$CfgCandidates = @(
  "${env:ProgramFiles(x86)}\VoipSwitch\VoipSwitch 2.0\voipswitch_config.xml",
  "$env:ProgramFiles\VoipSwitch\VoipSwitch 2.0\voipswitch_config.xml",
  "C:\VoipSwitch\voipswitch_config.xml"
)
New-Item -ItemType Directory -Force -Path $OutDir, $LogDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $LogDir ("backup-" + (Get-Date -Format "yyyyMMdd") + ".log")
function Log([string]$m) {
  $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
  Add-Content -Path $log -Value $line
  Write-Output $line
}
Log "START"
$cfgPath = $CfgCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cfgPath) { throw "voipswitch_config.xml not found" }
[xml]$xml = Get-Content -LiteralPath $cfgPath
$db = $xml.vpsconfig.database.param
$dbhost = ($db | Where-Object { $_.name -eq "ipaddr" }).value
$port   = ($db | Where-Object { $_.name -eq "port" }).value
$user   = ($db | Where-Object { $_.name -eq "username" }).value
$pass   = ($db | Where-Object { $_.name -eq "password" }).value
$dbname = ($db | Where-Object { $_.name -eq "dbname" }).value
if (-not $dbhost) { $dbhost = "127.0.0.1" }
if (-not $port)   { $port = "3306" }
if (-not $user)   { $user = "root" }
if (-not $dbname) { $dbname = "voipswitch" }
Log ("CONFIG source=$cfgPath host=$dbhost port=$port user=$user db=$dbname pass_len=" + ([string]$pass).Length)

$mysqldump = @(
  "C:\MySQL\bin\mysqldump.exe",
  "${env:ProgramFiles}\MySQL\MySQL Server 5.0\bin\mysqldump.exe",
  "${env:ProgramFiles(x86)}\MySQL\MySQL Server 5.0\bin\mysqldump.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $mysqldump) { $mysqldump = (Get-Command mysqldump -ErrorAction SilentlyContinue).Source }
if (-not $mysqldump) { throw "mysqldump.exe not found" }

$sql = Join-Path $OutDir ($dbname + "_" + $stamp + ".sql")
$zip = Join-Path $OutDir ($dbname + "_" + $stamp + ".zip")
$dumpArgs = @("--host=$dbhost","--port=$port","--user=$user","--single-transaction","--quick","--routines","--hex-blob","--result-file=$sql",$dbname)
if ($pass) { $dumpArgs = @("--password=$pass") + $dumpArgs }
Log "DUMP begin"
$p = Start-Process -FilePath $mysqldump -ArgumentList $dumpArgs -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { throw "mysqldump exit $($p.ExitCode)" }
if (-not (Test-Path $sql) -or (Get-Item $sql).Length -lt 100) { throw "sql missing or too small" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
$z = [System.IO.Compression.ZipFile]::Open($zip, "Create")
try { [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $sql, [IO.Path]::GetFileName($sql)) }
finally { $z.Dispose() }
Remove-Item $sql -Force
Log ("ZIP ok " + $zip)
if ($ShareDir) {
  New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null
  Copy-Item $zip (Join-Path $ShareDir ([IO.Path]::GetFileName($zip))) -Force
  Log "SHARE ok"
}
Log "SUCCESS"
