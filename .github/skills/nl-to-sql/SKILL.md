---
name: nl-to-sql
description: Turn a business question into verified PostgreSQL SQL using the connected MCP server. Clarifies ambiguous requests first, states assumptions, runs read-only SQL, and checks the result for join fan-out, NULL handling and sanity. Use for any business question that needs data from the database.
---

# Business question to SQL

Answer business questions with SQL that you have checked, not just generated.

## Steps

1. **Restate the question** in one sentence, with the metric, the grain (per order, per customer, per month) and the filters.
2. **Check for ambiguity.** If the question can reasonably mean two things that give different numbers, stop and ask one short clarifying question with the options (for example "customers" as `customer_id` or as `customer_unique_id`; "late" measured by timestamp or by date; revenue with or without freight; which order statuses count). Do not guess silently. If the user says to go ahead, pick the most standard reading and state it.
3. **Check the schema** before writing SQL. If you have not seen the tables this session, look at them first (see the `schema-guide` skill or `docs/schema-guide.md`). Never invent column names.
4. **Write the SQL** with explicit `JOIN ... ON` conditions, schema-qualified tables (`olist.orders`), and `LIMIT` when the result is a list. Prefer CTEs for multi-step logic. Follow `.github/instructions/sql-conventions.instructions.md`.
5. **Verify before you answer.** Run at least two of these checks, read-only:
   - Row-count check: does a base count match the expected population (for example orders delivered)?
   - Fan-out check: when you join a table that has several rows per key (order items, payments, reviews), compare `count(*)` with `count(DISTINCT key)`, and make sure you do not `SUM` a value from the "one" side after joining the "many" side.
   - NULL check: how many rows have NULL in the columns you filter or compare on?
   - Cross-check: compute the same number a second way (for example a total without the extra join).
6. **Answer** with: the number or table, the SQL you ran, the assumptions you made, and the checks you did with their results. Mention anything that could make the number differ (statuses excluded, rows dropped by an inner join).
7. If a check disagrees with your first result, say so and fix the SQL; show both queries.

## Rules

- Use a read-only MCP server for questions (`pg-crystaldba-restricted`, `pg-reference`, or `pg-toolbox` when one of its fixed tools fits). Say which one you use.
- Read-only SQL only, one statement per call. If the user asks you to change data, explain that you cannot do it from this server and ask them to use the DBA workflow.
- Do not run unbounded queries on big tables (`olist.geolocation` has about 1 million rows): aggregate or add `LIMIT`.
- Do not hide uncertainty. If you could not verify something, say so.
