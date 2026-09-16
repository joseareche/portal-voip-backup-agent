<#
.SYNOPSIS
  List desktop shortcuts (useful on WS2012 lab VMs to find VoIPSwitch launchers).
#>
$ErrorActionPreference = "Continue"
$sh = New-Object -ComObject WScript.Shell
$desktops = @(
  "$env:PUBLIC\Desktop",
  "$env:USERPROFILE\Desktop",
  "C:\Users\Administrator\Desktop"
)
foreach ($d in $desktops) {
  if (-not (Test-Path $d)) { continue }
  Get-ChildItem $d -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output ("NAME=" + $_.Name)
    if ($_.Extension -eq ".lnk") {
      $s = $sh.CreateShortcut($_.FullName)
      Write-Output ("TARGET=" + $s.TargetPath)
      Write-Output ("ARGS=" + $s.Arguments)
    }
  }
}
