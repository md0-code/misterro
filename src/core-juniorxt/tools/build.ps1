param(
    [ValidateSet('sim','test','quartus','package','assets','fetch')][string]$Action = 'test',
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs
)
$ErrorActionPreference = 'Stop'
$Action = $Action.ToLowerInvariant()
$projectRoot = Split-Path -Parent $PSScriptRoot
$linuxRoot = (& wsl -d Debian -e wslpath -a $projectRoot).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl -d Debian -e python3 -B "$linuxRoot/tools/build.py" $Action @ExtraArgs
exit $LASTEXITCODE
