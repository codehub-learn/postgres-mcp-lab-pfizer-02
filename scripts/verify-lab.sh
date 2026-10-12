#!/usr/bin/env bash
# Check that the lab is in the expected clean state. Exit code 0 only if every check passes.
# Usage: scripts/verify-lab.sh
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }
check() { # description, expected, actual
  if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1: expected '$2', got '$3'"; fi
}
sql() { # role, password, statement
  docker exec -e PGPASSWORD="$2" pgmcplab-db psql -h 127.0.0.1 -U "$1" -d "$POSTGRES_DB" -At -c "$3" 2>&1
}

echo "Database"
check "database healthy" healthy "$(docker inspect -f '{{.State.Health.Status}}' pgmcplab-db 2>/dev/null)"
check "orders rows"       99441   "$(sql postgres "$POSTGRES_PASSWORD" 'select count(*) from olist.orders')"
check "geolocation rows"  1000163 "$(sql postgres "$POSTGRES_PASSWORD" 'select count(*) from olist.geolocation')"
check "tables in olist"   9       "$(sql postgres "$POSTGRES_PASSWORD" "select count(*) from pg_tables where schemaname='olist'")"
check "extra indexes"     0       "$(sql postgres "$POSTGRES_PASSWORD" "select count(*) from pg_indexes where schemaname='olist' and indexname not like '%pkey'")"
check "extensions"        "hypopg,pg_stat_statements" "$(sql postgres "$POSTGRES_PASSWORD" "select string_agg(extname, ',' order by extname) from pg_extension where extname in ('hypopg','pg_stat_statements')")"

echo "Roles"
check "readonly can read"  99441 "$(sql mcp_readonly "$MCP_READONLY_PASSWORD" 'select count(*) from olist.orders')"
case "$(sql mcp_readonly "$MCP_READONLY_PASSWORD" "update olist.orders set order_status='x' where false")" in
  *ERROR*) ok "readonly write blocked" ;; *) bad "readonly write was NOT blocked" ;; esac
check "admin can create (and drop) an index" "CREATE INDEXDROP INDEX" \
  "$(sql mcp_admin "$MCP_ADMIN_PASSWORD" 'create index verify_tmp_idx on olist.orders(customer_id)' | tr -d '\n')$(sql mcp_admin "$MCP_ADMIN_PASSWORD" 'drop index olist.verify_tmp_idx' | tr -d '\n')"

echo "MCP servers (Inspector CLI inside the compose network)"
tools() { docker exec pgmcplab-inspector inspector --cli "$1" --transport "$2" --method tools/list 2>/dev/null \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin)['tools']))" 2>/dev/null || echo error; }
check "pg-reference tools"              1 "$(tools http://mcp-reference:8000/mcp http)"
check "pg-toolbox tools"                4 "$(tools http://mcp-toolbox:5000/mcp http)"
check "pg-crystaldba-restricted tools"  9 "$(tools http://mcp-crystaldba-restricted:8000/sse sse)"
check "pg-crystaldba-unrestricted tools" 9 "$(tools http://mcp-crystaldba-unrestricted:8000/sse sse)"

echo "Web UIs"
http() { # url; retry for up to 2 minutes (pgAdmin needs about a minute to initialise after a start)
  local code=000
  for _ in $(seq 1 40); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$1")"
    [ "$code" = 200 ] && break; sleep 3
  done; echo "$code"
}
check "pgAdmin HTTP"    200 "$(http http://127.0.0.1:5050/browser/)"
check "Inspector HTTP"  200 "$(http http://127.0.0.1:6274/)"

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || { echo "SOME CHECKS FAILED"; exit 1; }
