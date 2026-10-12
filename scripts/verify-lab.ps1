# Check that the lab is in the expected clean state. Exit code 0 only if every check passes.
# Usage: pwsh scripts/verify-lab.ps1
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
Get-Content .env | Where-Object { $_ -match '^\s*[A-Za-z_]+=' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; Set-Item "env:$($k.Trim())" $v.Trim() }
$script:fail = $false
function Check($desc, $expected, $actual) {
  if ("$expected" -eq "$actual") { Write-Host "  ok    $desc ($actual)" }
  else { Write-Host "  FAIL  ${desc}: expected '$expected', got '$actual'"; $script:fail = $true }
}
function Sql($role, $password, $stmt) {
  (docker exec -e "PGPASSWORD=$password" pgmcplab-db psql -h 127.0.0.1 -U $role -d $env:POSTGRES_DB -At -c $stmt 2>&1) -join ''
}
function Tools($url, $transport) {
  try {
    $j = docker exec pgmcplab-inspector inspector --cli $url --transport $transport --method tools/list 2>$null | Out-String | ConvertFrom-Json
    $j.tools.Count
  } catch { 'error' }
}
function Http($url) {
  # retry for up to 2 minutes (pgAdmin needs about a minute to initialise after a start)
  for ($i = 0; $i -lt 40; $i++) {
    try { $c = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 10).StatusCode; if ($c -eq 200) { return 200 } } catch { }
    Start-Sleep -Seconds 3
  }
  0
}

Write-Host 'Database'
Check 'database healthy' 'healthy' (docker inspect -f '{{.State.Health.Status}}' pgmcplab-db 2>$null)
Check 'orders rows' 99441 (Sql postgres $env:POSTGRES_PASSWORD 'select count(*) from olist.orders')
Check 'geolocation rows' 1000163 (Sql postgres $env:POSTGRES_PASSWORD 'select count(*) from olist.geolocation')
Check 'tables in olist' 9 (Sql postgres $env:POSTGRES_PASSWORD "select count(*) from pg_tables where schemaname='olist'")
Check 'extra indexes' 0 (Sql postgres $env:POSTGRES_PASSWORD "select count(*) from pg_indexes where schemaname='olist' and indexname not like '%pkey'")
Check 'extensions' 'hypopg,pg_stat_statements' (Sql postgres $env:POSTGRES_PASSWORD "select string_agg(extname, ',' order by extname) from pg_extension where extname in ('hypopg','pg_stat_statements')")

Write-Host 'Roles'
Check 'readonly can read' 99441 (Sql mcp_readonly $env:MCP_READONLY_PASSWORD 'select count(*) from olist.orders')
$w = Sql mcp_readonly $env:MCP_READONLY_PASSWORD "update olist.orders set order_status='x' where false"
if ($w -match 'ERROR') { Write-Host '  ok    readonly write blocked' } else { Write-Host '  FAIL  readonly write was NOT blocked'; $script:fail = $true }
$a = (Sql mcp_admin $env:MCP_ADMIN_PASSWORD 'create index verify_tmp_idx on olist.orders(customer_id)') + (Sql mcp_admin $env:MCP_ADMIN_PASSWORD 'drop index olist.verify_tmp_idx')
Check 'admin can create (and drop) an index' 'CREATE INDEXDROP INDEX' $a

Write-Host 'MCP servers (Inspector CLI inside the compose network)'
Check 'pg-reference tools' 1 (Tools 'http://mcp-reference:8000/mcp' 'http')
Check 'pg-toolbox tools' 4 (Tools 'http://mcp-toolbox:5000/mcp' 'http')
Check 'pg-crystaldba-restricted tools' 9 (Tools 'http://mcp-crystaldba-restricted:8000/sse' 'sse')
Check 'pg-crystaldba-unrestricted tools' 9 (Tools 'http://mcp-crystaldba-unrestricted:8000/sse' 'sse')

Write-Host 'Web UIs'
Check 'pgAdmin HTTP' 200 (Http 'http://127.0.0.1:5050/browser/')
Check 'Inspector HTTP' 200 (Http 'http://127.0.0.1:6274/')

if ($script:fail) { Write-Host 'SOME CHECKS FAILED'; exit 1 } else { Write-Host 'ALL CHECKS PASSED' }
