---
name: schema-guide
version: 1.1.0
description: Explore the connected PostgreSQL database through the MCP server (tables, columns, keys, relationships, constraints, indexes) and write a short engineer-facing schema guide to docs/schema-guide.md. Use when asked to explore, document or explain the database schema.
---

# Schema guide

Produce a short, accurate guide for an engineer who has never seen this database. Everything in it must come from what the MCP server returns, not from memory or guesses.

## Steps

1. Pick the MCP server. Use a read-only one (`pg-crystaldba-restricted`, `pg-reference` or `pg-toolbox`). Say which one you use. Do not use the unrestricted server for exploration.
2. Discover the schemas, then the tables in the application schema (`olist`). Tool hints:
   - crystaldba: `list_schemas`, `list_objects`, `get_object_details` (columns, constraints, indexes).
   - toolbox: `list_tables`.
   - reference (`query` only): query `information_schema` and `pg_catalog`, one SELECT per question.
3. For every table collect: purpose (from names and sample rows, say "inferred" when you infer), row count (`SELECT count(*)`), primary key, foreign keys (to which table and column), CHECK constraints, existing indexes.
4. Work out the relationships: the join path between the tables, and how many rows relate (one to many, many to many). Verify cardinality with a query before you state it (for example orders per customer, items per order).
5. Record anything surprising that you actually observed, such as a column that looks unique but is not, a missing foreign key, duplicate keys, NULL-heavy columns, or tables nothing references. Check with a query first.
6. Write `docs/schema-guide.md` with these sections, nothing more:
   - **Overview** (3 to 5 lines: what the data is, the date range if you checked it).
   - **Tables** (one table: name, rows, primary key, purpose).
   - **Relationships** (a Mermaid `erDiagram` in a ```mermaid fence: one entity per table with its key columns marked `PK`/`FK`, and one line per foreign key using crow's-foot cardinality from step 4, for example `customers ||--o{ orders : places`. Label each line with the verb and keep the diagram readable; list only key columns, not every column. Add a one-line note for any relationship that is not enforced by a foreign key.)
   - **Constraints and indexes** (what exists; note which foreign key columns have no index).
   - **Gotchas** (the surprises from step 5, each with the query or number that proves it).
   - **Useful starter queries** (3 short, read-only queries, each with a one-line description).
7. Keep it under about 120 lines. Tell the user the file path and list anything you could not verify.

## Rules

- Read-only SQL only. One statement per call. Add `LIMIT` to anything that returns rows.
- Do not edit data or schema. Do not paste credentials or connection strings.
- If a tool errors, report the error and try a different read-only way; do not switch to the unrestricted server to get around it.
