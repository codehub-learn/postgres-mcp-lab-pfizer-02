---
name: sql-safety-review
description: Review SQL that an agent generated (or that a person wrote) for correctness and safety problems in a PostgreSQL database, then give a corrected version. Use when asked to review, check, audit or "sanity check" a query, or before running generated SQL that changes data or could be expensive.
---

# SQL safety and correctness review

Review the SQL you are given (or the SQL you just generated) and report problems before anything runs.

## Checklist

**Safety**
- Does it change data or schema (`INSERT`, `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`, `ALTER`, `CREATE`, `GRANT`, `COPY ... FROM`)? On a read-only server it must not run. Say so and stop.
- `UPDATE` or `DELETE` without `WHERE`, or with a `WHERE` that matches more than intended? Count the rows it would touch with a `SELECT count(*)` first.
- More than one statement in one call, SQL built from text the user typed, or dynamic SQL (`EXECUTE`, `DO`)? Flag it.
- Does it read columns that look sensitive (names, emails, tokens)? Flag it and minimise the columns.

**Cost**
- Unbounded result on a large table (`SELECT *` from a table with many rows, no `LIMIT`, no aggregation)?
- Join without a join condition (cartesian product), or a join on a non-indexed column of a big table? Run `EXPLAIN` (no `ANALYZE` for anything that changes data) and read the plan: sequential scans on big tables, row estimates far from actual, nested loops over big sets.
- Correlated subquery executed per row?

**Correctness**
- Fan-out: a `SUM`/`COUNT` after joining a table with several rows per key (order items, payments, reviews). Compare `count(*)` with `count(DISTINCT key)`.
- Wrong grain or wrong key: for example counting `customer_id` when the person is `customer_unique_id`.
- NULL traps: `= NULL`, `NOT IN` with NULLs, comparing a NULL date, averages that ignore NULL rows.
- Status filters: are cancelled, unavailable or not-yet-delivered orders wrongly included or excluded?
- Timestamps vs dates, time zones, inclusive/exclusive ranges.
- `LEFT JOIN` turned into an inner join by a `WHERE` on the right-hand table.

## Output

1. **Verdict**: safe / safe with changes / do not run, in one line.
2. **Findings**: a short list, each with the line or clause, why it is a problem, and the evidence (a count or plan fragment you got by running a read-only check).
3. **Corrected SQL**: only if you can verify it. Run the corrected query (read-only) and compare it with the original result when both are safe to run.
4. If a fix needs a write, say what to run and on which server, but do not run it yourself.

## Rules

- Never "fix" a failing write by switching to another server or role. Report that the server blocked it and why that is correct.
- Use only read-only checks (`SELECT`, `EXPLAIN`). Never use `EXPLAIN ANALYZE` on a statement that modifies data.
