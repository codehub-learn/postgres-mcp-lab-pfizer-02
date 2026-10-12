# Lab guide: Connecting Agents to Real Data, PostgreSQL MCP Server Lab

Use this guide to do the lab, and to do it again on your own. An AI agent talks to a PostgreSQL 18 database (real Olist e-commerce data) through MCP servers running in Docker.

The course repo grows as the class moves on. You start with the files for Unit 1; the files for Units 2 and 3 arrive with `git pull` when your instructor releases them. [Files you receive](#files-you-receive-with-each-release) explains what each batch of files is for.

## How to read this guide

Only the lines marked **Run** and **Paste** are things you execute.

| Label | Meaning |
|---|---|
| **Run** | a command for a terminal, in the course folder |
| **Paste** | a prompt for the agent; the text is in the named `prompts/` file (the number is the block id) or given here |
| **Open** | something to look at in a browser |
| **Check** | what you should see; use it to verify the agent |

Where your agent matters, use the column for the one you picked.

| | GitHub Copilot CLI | Claude Code |
|---|---|---|
| Start the agent in the course folder | `copilot` | `claude` |
| First start | answer **yes** to trust the folder, or `.mcp.json` is not loaded | approve the project MCP servers from `.mcp.json` |
| List the MCP servers | `/mcp show` | `/mcp` |
| List the skills | `/skills` | `/skills` |
| List the agents | `/agent` | `/agents` |
| Use an agent | `/agent`, choose it | start with `claude --agent <name>` |
| Reload after new files arrive | restart `copilot` | restart `claude` |

## Before you start

| Need | Check |
|---|---|
| Docker Desktop running, 4 GB or more | `docker info` |
| Your agent, logged in | `copilot --version` or `claude --version` |
| Node.js 24 (the safety hook runs on it, from Unit 2) | `node --version` |
| Git | `git --version` |
| Free ports 5432, 5050, 5000, 6274, 6277, 8100 to 8102 | |

---

## Unit 1. Setting Up the Lab

### Topic 1, step 1: Launch the Postgres image and load the dataset

The database is the official `postgres:18.6-alpine` image plus the `hypopg` extension. On the first start Postgres runs every script in `db/init/` once: it creates two roles (`mcp_readonly` can only SELECT, `mcp_admin` can change the schema), creates the `olist` schema and loads nine CSV files, about 1.5 million rows of real, unmodified data. The role, not the prompt, is the security boundary.

**Run** (bash):

```bash
git clone <course-repo-url> postgres-mcp-lab
cd postgres-mcp-lab
cp .env.example .env
bash scripts/fetch-dataset.sh
docker compose --profile mcp up -d --build
bash scripts/verify-lab.sh
```

**Run** (PowerShell):

```powershell
git clone <course-repo-url> postgres-mcp-lab
cd postgres-mcp-lab
Copy-Item .env.example .env
pwsh -File scripts/fetch-dataset.ps1
docker compose --profile mcp up -d --build
pwsh -File scripts/verify-lab.ps1
```

**Check:** the dataset download is 125 MB and checksum verified; the first `up` takes 2 to 6 minutes; the last line of `verify-lab` is `ALL CHECKS PASSED` (15 checks).

**Run:** `docker compose --profile mcp ps`. **Check:** 7 containers up, `db` healthy.

**Open:** http://127.0.0.1:5050 (pgAdmin; log in with `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` from `.env`), then `lab > Schemas > olist > Tables`. **Check:** 9 tables; `orders` has 99,441 rows.

### Topic 1, step 2: Choose and configure an MCP server

Four MCP servers run in containers against the same database. Pick the narrowest server that can answer the question and let the database role enforce it.

| Server (name in `.mcp.json`) | Tools | Free SQL | DB role |
|---|---|---|---|
| `pg-reference` (reference server, archived) | 1 (`query`) | yes | `mcp_readonly` |
| `pg-crystaldba-restricted` | 9 | yes, parsed and read-only | `mcp_readonly` |
| `pg-crystaldba-unrestricted` | 9 | yes, anything | `mcp_admin` |
| `pg-toolbox` (Google MCP Toolbox) | 4 fixed tools | no | `mcp_readonly` |

**Open (optional, 5 min):** http://127.0.0.1:6274, the MCP Inspector (the URL with the token is in the `pgmcplab-inspector` container log). The four servers are already registered: connect one and open its Tools tab.

### Topic 1, step 3: Register the servers with the agent and verify

The agent finds the servers in `.mcp.json` at the project root. Two entries are `http` (Streamable HTTP, the current transport) and two are `sse` (legacy; crystaldba offers nothing else). Open the file and look at `type` and `url`.

**Run:** start your agent in the course folder (`copilot` or `claude`), trust or approve when asked, then list the servers (see the table above).

**Check:** `pg-reference`, `pg-crystaldba-restricted`, `pg-crystaldba-unrestricted`, `pg-toolbox`. If Copilot shows none, the folder is not trusted or `copilot` was not started in the project root.

**Paste:** `prompts/00-verify-connection.md`. Paste the **free-form SQL** block once for each of `pg-reference`, `pg-crystaldba-restricted`, `pg-crystaldba-unrestricted` (replace `<server>`), then the **Toolbox** block.

| Server | `count(*)` orders | `UPDATE ... WHERE false` | `current_user` |
|---|---|---|---|
| `pg-reference` | 99441 | fails: read-only transaction | `mcp_readonly` |
| `pg-crystaldba-restricted` | 99441 | fails: query validation | `mcp_readonly` |
| `pg-crystaldba-unrestricted` | 99441 | succeeds, 0 rows | `mcp_admin` |
| `pg-toolbox` | 9 tables listed | no tool accepts SQL | top late states AL, MA, PI |

---

## Unit 2. Discovering and Querying the Database

**First:** run `git pull` when your instructor says release 2 is out (or `git pull` again before you repeat this unit), then restart the agent. What arrives is described in [Release 2](#release-2-start-of-unit-2-git-pull).

**Check:** skills `schema-guide`, `nl-to-sql`, `sql-safety-review`; agent `data-analyst`. (Copilot only: `.github/copilot-instructions.md` already mentions the Unit 3 agent and skills; ignore those for now.)

Use the `data-analyst` agent for the whole unit (Copilot: `/agent`, choose it; Claude Code: `claude --agent data-analyst`). It uses read-only servers only.

### Topic 2, step 1: Explore the schema through the agent

Let the agent discover the database the way a new engineer would. Watch which tools it calls and whether it backs its claims with queries.

**Paste:** `prompts/10-schema-discovery.md`, blocks **10.1**, then **10.2**. Optional: **10.3** (the same task on `pg-reference` and `pg-toolbox`).

**Check:**
- 10.1: 9 tables with row counts, primary keys and 6 foreign keys; `geolocation` has no key.
- 10.2: the relationships; no indexes beyond primary keys, so `order_items.seller_id`, `order_items.product_id`, `orders.customer_id` and `order_reviews.order_id` are unindexed.
- 10.3: the reference server needs `information_schema` queries; Toolbox cannot explore at all.

### Topic 2, step 2: Generate a short engineer-facing schema guide

**Paste:** `prompts/10-schema-discovery.md`, block **10.4**.

**Check:**
- `docs/schema-guide.md` is written (skill `schema-guide`), with a Mermaid ER diagram and a Gotchas section.
- It should mention: `customer_id` is per order (99,441 ids vs 96,096 people), several rows per order in items, payments and reviews, non-unique `review_id`, no indexes on foreign keys.
- Challenge any claim that has no query behind it.

### Topic 3, step 1: Turn business questions into SQL

Each question has a known answer, computed with plain SQL. The agent's job is to match it and to say which definition it used.

**Paste:** `prompts/20-business-questions.md`, **Q1**, **Q2**, **Q4**, one at a time.

**Check:**
- Q1: bed_bath_table 490,597; watches_gifts 475,611; health_beauty 473,833.
- Q2: 8.11 percent late (7,826 of 96,470); the agent states its definition.
- Q4: revenue 5,962,902.01 over 43,428 orders, average review 4.16. The trap is 5,997,887.96 (join fan-out).

### Topic 3, step 2: Verify results and refine ambiguous requests

**Paste:** `prompts/20-business-questions.md`, **Q3** ("How many customers do we have?"). After the agent answers, paste:

```text
I mean people.
```

Then **Q7**, followed by:

```text
Now show their average review score too.
```

**Check:**
- Q3: the agent asks, or gives both readings: 99,441 vs 96,096. After "I mean people": 96,096.
- Q7: after adding the reviews join the agent re-checks for fan-out and says how it counted late items.

### Topic 3, step 3: Recognize and correct wrong or unsafe queries

The agent sometimes writes SQL that runs and is wrong, or risky. Use it as a reviewer. Do not run the bad queries yourself.

**Paste:** `prompts/30-review-generated-sql.md`: the intro prompt, then queries **A** to **F** one at a time (skill `sql-safety-review`).

**Check:** a verdict, evidence and a corrected query for each:
- A: cartesian join (planner cost about 98.8 million).
- B: fan-out, 5,997,887.96 instead of 5,962,902.01.
- C: `= NULL` returns 0 instead of 2,965.
- D: unbounded read of a million rows.
- E: `DELETE` without WHERE, refused.
- F: per-row subquery, about 2.5 s for 50 rows.

**Paste:** `prompts/20-business-questions.md`, **Q5** (delete canceled orders) and **Q6** (all geolocation in SP).

**Check:**
- Q5: no change is made; the hook or the read-only role refuses; 625 canceled and 609 unavailable orders would be affected; the agent does not switch to the unrestricted server.
- Q6: the agent does not dump 404,268 rows; it offers an aggregate or a `LIMIT`.

**Paste**, live hook demo:

```text
Use the MCP server "pg-reference" and run exactly: delete from olist.orders where 1=1
```

**Check:** denied with a reason; every SQL call, allowed or not, is logged in `logs/queries.log`.

Unit 2 only reads, so the database is still clean for Unit 3.

---

## Unit 3. Optimizing and Evolving the Schema

**First:** `git pull` for release 3, then restart the agent. What arrives is described in [Release 3](#release-3-start-of-unit-3-git-pull).

**Check:** 5 skills in total (`explain-tuning` and `migration-author` are new); agents `data-analyst` and `dba`.

Use the `dba` agent for the whole unit (Copilot: `/agent`, choose it; Claude Code: `claude --agent dba`). It may use `pg-crystaldba-unrestricted` only after you confirm each schema change.

**Run:** `bash scripts/verify-lab.sh` (PowerShell: `pwsh -File scripts/verify-lab.ps1`) to confirm a clean database with no extra indexes. **Check:** `ALL CHECKS PASSED`.

### Topic 4, step 1: Diagnose a slow query with EXPLAIN and tune it

Cost estimates are a hypothesis; measured time is the evidence.

**Paste:** `prompts/40-tuning.md`, blocks **40.1**, **40.2**, **40.3**.

**Check:**
- 40.1: about 2.0 to 2.4 s; `Seq Scan on geolocation` repeated with `loops=50`; the fix is an index on `geolocation.geolocation_zip_code_prefix`.
- 40.2 (hypothetical index, nothing created): top-level cost falls from about 1,067,789 to about 10,760 and the plan becomes an Index Scan.
- 40.3 (advisor on the seller scorecard): it recommends 3 indexes (estimated 1.7 times better), but the real time stays about 31 to 36 ms; a good agent recommends not adding them.

### Topic 4, step 2: Adjust the schema (indexes, derived structures)

Read the `up` and `down` files before you confirm. Nothing changes the schema outside `db/migrations/`.

**Paste:** `prompts/40-tuning.md`, block **40.4**. Read the files the agent shows, then confirm:

```text
Yes, apply it.
```

Then **40.5**.

**Check:**
- `db/migrations/001_tuning_indexes.up.sql` and `.down.sql` are written and applied with `scripts/apply-sql` (`.sh` or `.ps1`).
- The slow query now takes about 65 to 100 ms (20 to 30 times faster).
- 40.5: the new index is about 7 MB; the agent mentions write cost; top queries from `pg_stat_statements`.

### Topic 4, step 3: Generate SQL and a migration for a new reporting need

**Paste:** `prompts/50-new-report.md`, block **50.1**. Read the migration files, then confirm:

```text
Yes, apply it.
```

Then **50.2** (check) and **50.3** (refresh and rollback).

**Check:**
- 50.1: the agent states its definitions, prototypes the query read-only, times it (about 200 ms for May 2018), proposes a materialized view with a unique index and shows the migration files first.
- 50.2: `olist.seller_monthly_scorecard` with 16,065 rows; the top 10 for May 2018 from the view in under 1 ms; top seller `7d13fca15225358621be4086e1eb0964` (205 orders, revenue 31,286.81, review 4.14, late 11.7 percent).
- 50.3: refresh as the read-only role fails; `REFRESH MATERIALIZED VIEW CONCURRENTLY` works as admin; applying the `down` file removes the view.

---

## Files you receive with each release

The course repo is released in three batches. Release 1 is what you clone; releases 2 and 3 arrive with `git pull`. Files are only ever added, so a pull never overwrites your work. After each pull, restart your agent so it picks up the new components. You get the files for your agent only (Copilot CLI or Claude Code); the shared files are the same for both.

### Release 1: start of Unit 1 (`git clone`)

| File or folder | Role |
|---|---|
| `docker-compose.yml`, `Dockerfile.postgres` | Define the stack: Postgres 18 with `hypopg` and `pg_stat_statements`, pgAdmin, the MCP Inspector and the four MCP servers. |
| `.env.example` | Template for `.env` (throwaway lab credentials and ports). You copy it; `.env` is never committed. |
| `db/init/` | SQL that runs once on the first start: creates the roles `mcp_readonly` and `mcp_admin`, the `olist` schema, the tables and loads the data. |
| `db/data/` | Where `fetch-dataset` puts the downloaded CSV files (not in git). |
| `db/migrations/` | Empty at first; your schema changes are written here in Unit 3. |
| `mcp/` | Configuration for the containers around the database: the reference server build, the Toolbox tools file, the Inspector catalog and the pgAdmin server list. |
| `.mcp.json` | Tells the agent which four MCP servers exist and where they listen. |
| `AGENTS.md` | Standing instructions for the agent: the stack, safety rules (read-only by default, no DROP/TRUNCATE, ask before DDL), migration and SQL habits. Claude Code reads it through `CLAUDE.md` (`@AGENTS.md`); Copilot reads it directly. |
| `CLAUDE.md` (Claude Code only) | One line that imports `AGENTS.md`. |
| `scripts/fetch-dataset.*` | Downloads the Olist CSV files and verifies the checksum. |
| `scripts/verify-lab.*` | Runs 15 checks on the stack and data; ends with `ALL CHECKS PASSED`. |
| `scripts/reset-lab.*` | Throws away the database and your files and rebuilds a clean lab. |
| `prompts/00-verify-connection.md` | Prompts that test each MCP server. |
| `logs/` | Where the hook writes `queries.log` from Unit 2. |
| `LAB-GUIDE.md` | This guide. |
| `.gitignore`, `.gitattributes` | Keep `.env`, data and logs out of git; keep line endings stable. |

### Release 2: start of Unit 2 (`git pull`)

| File or folder | Role |
|---|---|
| `prompts/10-schema-discovery.md`, `20-business-questions.md`, `30-review-generated-sql.md` | The prompts for Topics 2 and 3. |
| `scripts/hooks/guard-sql.mjs` | The safety hook. Runs before every SQL call to the `pg-*` servers: always blocks DROP, TRUNCATE and UPDATE/DELETE without WHERE; on the read-only servers blocks anything that changes data or schema; logs every call to `logs/queries.log`. |
| Copilot: `.github/hooks/guard-sql.json` | Registers the hook with Copilot CLI. |
| Claude Code: `.claude/settings.json` | Registers the hook with Claude Code. |
| Copilot: `.github/copilot-instructions.md` | Always-on instructions for Copilot (the Copilot counterpart of `CLAUDE.md`). |
| Copilot: `.github/instructions/sql-conventions.instructions.md` | SQL style rules, applied when Copilot works on SQL files. |
| Claude Code: `.claude/rules/sql-conventions.md` | The same SQL style rules for Claude Code. |
| Skill `schema-guide` | Explores the database and writes `docs/schema-guide.md` with a Mermaid ER diagram and gotchas. |
| Skill `nl-to-sql` | Turns a business question into SQL: clarifies, states assumptions, runs it read-only, checks for fan-out and NULLs. |
| Skill `sql-safety-review` | Reviews SQL for correctness and safety and returns a corrected version. |
| Agent `data-analyst` | A read-only analyst. It can only use the read-only servers and never changes data or schema. |

Skills and agents live in `.github/skills/` and `.github/agents/` for Copilot, and in `.claude/skills/` and `.claude/agents/` for Claude Code.

### Release 3: start of Unit 3 (`git pull`)

| File or folder | Role |
|---|---|
| `prompts/40-tuning.md`, `50-new-report.md` | The prompts for Topic 4. |
| `db/queries/` | The queries to tune: `slow-customer-geolocation.sql` (the slow one), `seller-scorecard.sql`, and the raw and materialized-view versions of the seller report. |
| `scripts/apply-sql.*` | Applies one migration file as `mcp_admin` in a single transaction and records it in `public.schema_migrations`. Use the `.down.sql` file to roll back. |
| Skill `explain-tuning` | Diagnoses a slow query with `EXPLAIN (ANALYZE, BUFFERS)`, tests hypothetical indexes with hypopg and the index advisor, and measures before and after. |
| Skill `migration-author` | Writes a reversible migration (`up` and `down`) for a new index, view or table, and applies it safely. |
| Agent `dba` | Tunes queries and changes the schema. It may use the unrestricted server only after you confirm each schema change. |
| Copilot: `.github/instructions/migrations.instructions.md` | Migration rules for Copilot (naming, rollback, no data edits). |
| Claude Code: `.claude/rules/migrations.md` | The same migration rules for Claude Code. |

---

## Start over

**Run** (bash):

```bash
bash scripts/reset-lab.sh
bash scripts/verify-lab.sh
```

**Run** (PowerShell):

```powershell
pwsh -File scripts/reset-lab.ps1
pwsh -File scripts/verify-lab.ps1
```

**Check:** the reset drops the database volume, removes the files you created and reloads the data with cached images (about 2 to 3 minutes); `ALL CHECKS PASSED`. `verify-lab` fails on "extra indexes" while a tuning migration is applied; that is expected until you reset.

To stop everything: `docker compose --profile mcp down -v`.

## Files you create during the lab

| What | When |
|---|---|
| `.env`, `db/data/*.csv`, Docker containers and volume | Unit 1 |
| `logs/queries.log` | the hook, on every SQL call (from Unit 2) |
| `docs/schema-guide.md` | Topic 2, step 2 |
| `db/migrations/001_*` and `002_*` (`up` and `down`) | Topic 4, steps 2 and 3 |
| index on `geolocation`, view `olist.seller_monthly_scorecard`, rows in `public.schema_migrations` | when the migrations are applied |

## If something goes wrong

| Symptom | Likely cause and fix |
|---|---|
| The agent shows no MCP servers | Copilot: the folder is not trusted, or `copilot` was not started in the course folder. Claude Code: you did not approve the project servers; open `/mcp`. Restart the agent after fixing. |
| `docker compose up` fails on a port | Another program uses 5432, 5050, 5000, 6274, 6277 or 8100 to 8102. Stop it, or change the port in `.env`. |
| New skills or agents do not appear after `git pull` | Restart the agent; it only reads them at startup. |
| `verify-lab` reports extra indexes | A tuning migration is still applied. Roll it back with its `.down.sql` file, or run `reset-lab`. |
| A query times out on the restricted server | Expected on big joins without indexes (30 second limit). Narrow the query or add `LIMIT`. |
