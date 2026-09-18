$ErrorActionPreference = 'Stop'
$archive = Join-Path $PSScriptRoot 'AutoHotkey.zip'
$runtime = Join-Path $PSScriptRoot 'AutoHotkey'
$uri = 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v1.1.37.02/AutoHotkey_1.1.37.02.zip'
Invoke-WebRequest -Uri $uri -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
Write-Output "Portable AutoHotkey runtime: $runtime"
