<#
.SYNOPSIS
  Peek VoIPSwitch database config with passwords redacted.
.DESCRIPTION
  Reads well-known voipswitch_config.xml / Database.config / voipbox_config.xml
  and prints a truncated dump where password-like values are replaced with ***.
#>
$files = @(
  "${env:ProgramFiles(x86)}\VoipSwitch\VoipSwitch 2.0\voipswitch_config.xml",
  "$env:ProgramFiles\VoipSwitch\VoipSwitch 2.0\voipswitch_config.xml",
  "${env:ProgramFiles(x86)}\VoipSwitch\VoipSwitch 2.0\VSM\Database.config",
  "${env:ProgramFiles(x86)}\VoipSwitch\VoipSwitch 2.0\voipbox_config.xml",
  "C:\VoipSwitch\voipswitch_config.xml"
)
foreach ($p in $files) {
  Write-Output ("==== " + $p)
  if (-not (Test-Path $p)) { Write-Output "MISSING"; continue }
  $raw = Get-Content -LiteralPath $p -Raw
  $red = [regex]::Replace($raw, '(?i)(password|passwd|pwd)(["''\s:=]*)([^<"''\s]+)', '${1}${2}***')
  $red = [regex]::Replace($red, '(?i)(connpassword|ConnPassword)(["''\s:=]*)([^<"''\s]+)', '${1}${2}***')
  $n = [Math]::Min(3000, $red.Length)
  Write-Output $red.Substring(0, $n)
  Write-Output ""
}
