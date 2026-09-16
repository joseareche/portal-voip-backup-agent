<#
.SYNOPSIS
  Find VoIPSwitch config files that mention MySQL / password keywords.
.DESCRIPTION
  Read-only. Prints matching FILE= paths only — never the secret values.
#>
$ErrorActionPreference = "Continue"
$roots = @(
  "${env:ProgramFiles(x86)}\VoipSwitch",
  "$env:ProgramFiles\VoipSwitch",
  "${env:ProgramFiles(x86)}\VoipBox 3.0",
  "$env:ProgramFiles\VoipBox 3.0",
  "C:\VoipSwitch"
)
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem $root -Recurse -Include *.ini,*.xml,*.config,*.conf,*.cfg -ErrorAction SilentlyContinue | ForEach-Object {
    $t = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $t) { return }
    if ($t -match '(?i)(mysql|password|passwd|pwd|database|dbname)' -and $t -match '(?i)(password|passwd|pwd|mysql)') {
      Write-Output ("FILE=" + $_.FullName)
    }
  }
}
