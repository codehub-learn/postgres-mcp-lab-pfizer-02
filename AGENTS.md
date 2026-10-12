# AGENTS.md

Lab: "Connecting Agents to Real Data: PostgreSQL MCP Server Lab". An AI agent talks to a PostgreSQL 18 database through MCP servers running in Docker.

## Stack

- Database: `postgres:18.6-alpine` (custom image adds `hypopg`; `pg_stat_statements` preloaded). Dataset: Olist Brazilian e-commerce (real data, loaded unmodified).
- `docker-compose.yml` runs the database, pgAdmin, MCP Inspector and the MCP servers under test.
- MCP servers: reference read-only Postgres MCP (via bridge), crystaldba `postgres-mcp` (restricted and unrestricted), Google MCP Toolbox. Registered in `.mcp.json`.
- Two DB roles: `mcp_readonly` (SELECT only) and `mcp_admin` (can change schema). The role is the security boundary, not a prompt and not a read-only transaction.

## Safety rules for the agent

- Default to the read-only MCP servers. Use the unrestricted server only when the task needs DDL, and say so first.
- Never run DROP, TRUNCATE, or DELETE/UPDATE without a WHERE clause. Ask before any DDL.
- Show the SQL before running anything that changes data or schema.
- Put schema changes in a versioned file under `db/migrations/` with a rollback, not as ad hoc statements.
- Do not edit the dataset rows. Only constraints, indexes and derived structures may be added.

## Working with SQL

- Verify results: check row counts, look for fan-out from joins, and state assumptions.
- If a business question is ambiguous, ask a clarifying question before writing SQL.
- Use EXPLAIN (ANALYZE, BUFFERS) before and after tuning, and report both timings.

## Repo layout

- `db/init/`: init SQL. `db/queries/`: lab queries to tune. `db/migrations/`: versioned migrations (`NNN_name.up.sql` and `.down.sql`, applied with `scripts/apply-sql.sh` or `.ps1`; reference versions in `docs/reference/migrations/`). `db/data/`: downloaded dataset (gitignored).
- `prompts/`: copy/paste prompts for learners. `docs/`: runbook and schema guide. `scripts/`: fetch, reset and export scripts (`.sh` and `.ps1`).

## Style

- Plain prose, no em dashes, write like a human.
