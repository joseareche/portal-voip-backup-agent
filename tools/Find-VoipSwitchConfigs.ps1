<#
.SYNOPSIS
  VoIPSwitch / VoipBox config locator for Windows Server (2012 R2+).
.DESCRIPTION
  Read-only inventory of likely configuration files under common install roots.
  Does not print password values. Safe to run on a live softswitch host.
#>
$ErrorActionPreference = "Continue"
$roots = @(
  "${env:ProgramFiles(x86)}\VoipSwitch",
  "$env:ProgramFiles\VoipSwitch",
  "${env:ProgramFiles(x86)}\VoipBox 3.0",
  "$env:ProgramFiles\VoipBox 3.0",
  "C:\VoipSwitch",
  "C:\MySQL",
  "C:\PortalVoiceBox"
)
Write-Output "=== install roots present ==="
foreach ($r in $roots) {
  if (Test-Path $r) { Write-Output ("OK  " + $r) } else { Write-Output ("--  " + $r) }
}
Write-Output ""
Write-Output "=== config candidates (first 120) ==="
foreach ($r in $roots) {
  if (-not (Test-Path $r)) { continue }
  Get-ChildItem $r -Recurse -Include *.ini,*.xml,*.config,*.conf,*.json,*.cfg -ErrorAction SilentlyContinue |
    Select-Object -First 120 FullName, Length |
    ForEach-Object { "{0}`t{1}" -f $_.Length, $_.FullName }
}
Write-Output ""
Write-Output "=== my.ini head (if present) ==="
$my = @("C:\MySQL\my.ini", "$env:ProgramFiles\MySQL\MySQL Server 5.0\my.ini") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($my) {
  Write-Output ("FILE=" + $my)
  Get-Content $my -ErrorAction SilentlyContinue | Select-Object -First 60
} else {
  Write-Output "my.ini not found in common paths"
}
