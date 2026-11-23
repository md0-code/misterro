param([Parameter(Position=0)][string]$Action='test',[Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$linuxRoot=(& wsl -d Debian -e wslpath -a $projectRoot).Trim()
& wsl -d Debian -e python3 -B "$linuxRoot/tools/build.py" $Action @ExtraArgs
exit $LASTEXITCODE
