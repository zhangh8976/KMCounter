param([string]$AutoHotkey = (Join-Path $PSScriptRoot 'AutoHotkey\AutoHotkeyU64.exe'))
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (!(Test-Path -LiteralPath $AutoHotkey)) { throw '先运行 tools\SetupRuntime.ps1 下载 AutoHotkey v1.1.37.02。' }
foreach ($mode in @('--self-test', '--smoke')) {
    $stdout = Join-Path $project 'tests\results.txt'
    $stderr = Join-Path $project 'tests\errors.txt'
    $run = Start-Process -FilePath $AutoHotkey -ArgumentList '/ErrorStdOut', ('"' + (Join-Path $project 'KMCounter.ahk') + '"'), $mode -WorkingDirectory $project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Get-Content -LiteralPath $stdout, $stderr
    if ($run.ExitCode -ne 0) { exit $run.ExitCode }
}
