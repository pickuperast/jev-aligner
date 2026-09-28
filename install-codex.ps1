$ErrorActionPreference = 'Stop'

$codex = Join-Path $env:USERPROFILE '.codex'
$plugin = Join-Path $codex 'plugins\jev'
$hooksFile = Join-Path $codex 'hooks.json'

$go = (Get-Command go -ErrorAction SilentlyContinue).Source
if (-not $go) { $go = Join-Path $env:LOCALAPPDATA 'jev\go\go\bin\go.exe' }
if (-not (Test-Path $go)) {
    throw 'Go 1.26.1+ is required. Install Go, reopen PowerShell, then rerun this script.'
}
New-Item -ItemType Directory -Force -Path (Join-Path $plugin 'bin') | Out-Null
Push-Location $PSScriptRoot
try { & $go build -o (Join-Path $plugin 'bin\jev.exe') .\cmd\jev } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'Building jev failed.' }

$config = if (Test-Path $hooksFile) {
    Get-Content -Raw $hooksFile | ConvertFrom-Json -AsHashtable
} else { @{} }
if (-not $config.ContainsKey('hooks')) { $config.hooks = @{} }
if (-not $config.hooks.ContainsKey('PreToolUse')) { $config.hooks.PreToolUse = @() }

$command = '"' + (Join-Path $plugin 'bin\jev.exe') + '" hook read'
$config.hooks.PreToolUse = @($config.hooks.PreToolUse | Where-Object {
    -not ($_.matcher -eq 'Read|read_file' -and @($_.hooks | Where-Object { $_.command -eq $command }).Count -gt 0)
}) + @(@{
    matcher = 'Read|read_file'
    hooks = @(@{ type = 'command'; command = $command; timeout = 20 })
})

New-Item -ItemType Directory -Force -Path $codex | Out-Null
$config | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 $hooksFile
Write-Host "jev installed for Codex. Hook config: $hooksFile"
Write-Host 'Restart Codex and trust the hook when prompted. TYPESAFE_API_KEY is read from your Windows user environment.'
