#!/bin/sh
# Create the two roles the MCP servers connect with. Passwords come from the container env.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v ro_pw="$MCP_READONLY_PASSWORD" -v admin_pw="$MCP_ADMIN_PASSWORD" <<'SQL'
CREATE ROLE mcp_readonly LOGIN PASSWORD :'ro_pw';
CREATE ROLE mcp_admin    LOGIN PASSWORD :'admin_pw';
SQL
