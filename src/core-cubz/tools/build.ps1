param(
    [ValidateSet('sim','test','lint','quartus','package','assets','fetch')][string]$Action = 'test',
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs
)
$ErrorActionPreference = 'Stop'
$Action = $Action.ToLowerInvariant()
$projectRoot = Split-Path -Parent $PSScriptRoot
$linuxRoot = (& wsl -e wslpath -a $projectRoot).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl -e python3 -B "$linuxRoot/tools/build.py" $Action @ExtraArgs
exit $LASTEXITCODE
