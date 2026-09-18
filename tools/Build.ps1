param([ValidatePattern('^[A-Za-z0-9_.-]+\.exe$')][string]$OutputName = 'KMCounter.exe')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $PSScriptRoot 'AutoHotkey\Compiler\Ahk2Exe.exe'
$base = Join-Path $PSScriptRoot 'AutoHotkey\Compiler\Unicode 64-bit.bin'
if (!(Test-Path -LiteralPath $compiler)) { throw '先运行 tools\SetupRuntime.ps1。' }
$arguments = @('/in', ('"' + (Join-Path $project 'KMCounter.ahk') + '"'), '/out', ('"' + (Join-Path $project $OutputName) + '"'), '/base', ('"' + $base + '"'), '/icon', ('"' + (Join-Path $project 'resouces\KMCounter.ico') + '"'), '/silent', 'verbose')
$build = Start-Process -FilePath $compiler -ArgumentList $arguments -WorkingDirectory $project -WindowStyle Hidden -Wait -PassThru
if ($build.ExitCode -ne 0) { throw "Compiler exit code: $($build.ExitCode)" }
Get-Item -LiteralPath (Join-Path $project $OutputName) | Select-Object FullName, Length
