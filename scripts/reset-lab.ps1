# Reset the lab to the clean baseline: delete the database volume, remove learner-made artifacts,
# rebuild, and wait until the database is healthy.
# Usage: pwsh scripts/reset-lab.ps1 [-KeepLearnerFiles]
param([switch]$KeepLearnerFiles)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Test-Path .env)) { throw 'missing .env (copy .env.example to .env)' }

Write-Host '== dataset'
& pwsh -NoProfile -File scripts/fetch-dataset.ps1 | Out-Null
Write-Host 'dataset ok'

Write-Host '== stop and delete the database volume'
docker compose --profile mcp down -v
if ($LASTEXITCODE -ne 0) { throw 'docker compose down failed' }

if (-not $KeepLearnerFiles) {
  Write-Host '== remove files created by learners and agents'
  Get-ChildItem db/migrations -File | Where-Object { $_.Name -ne '.gitkeep' } | Remove-Item -Force
  Remove-Item docs/schema-guide.md, logs/queries.log -Force -ErrorAction SilentlyContinue
}

Write-Host '== start everything'
docker compose --profile mcp up -d --build
if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }

Write-Host '== wait for the database'
$status = ''
for ($i = 0; $i -lt 300; $i++) {
  $status = (docker inspect -f '{{.State.Health.Status}}' pgmcplab-db 2>$null)
  if ($status -eq 'healthy') { break }
  Start-Sleep -Seconds 3
}
if ($status -ne 'healthy') { throw 'database did not become healthy' }
Write-Host 'lab reset: database healthy. Run scripts/verify-lab.ps1 to check.'
