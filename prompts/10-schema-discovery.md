# 10 Discover the schema

Goal: the agent explores the database through the MCP server and produces a short engineer-facing guide.
Use a read-only server. Paste the prompts one at a time.

## 10.1 Open exploration

```text
Use the MCP server "pg-crystaldba-restricted". List the schemas, then the tables in the "olist" schema.
For each table tell me the number of rows, the primary key, and the foreign keys. Read only.
```

Look for: all 9 tables, row counts matching the runbook (orders 99,441; geolocation 1,000,163), 6 foreign keys, and that `geolocation` has no key.

## 10.2 Relationships and constraints

```text
Draw the relationships between the olist tables (which table points to which, and one-to-many or many-to-many).
List every CHECK constraint and every index. Which foreign key columns have no index?
```

Look for: no indexes beyond primary keys, so `order_items.seller_id`, `order_items.product_id`, `orders.customer_id` and `order_reviews.order_id` are unindexed.

## 10.3 Compare servers (optional)

Repeat 10.1 with `pg-reference` (it only has a `query` tool, so the agent must query `information_schema`) and with `pg-toolbox` (fixed tools only). Note how much work the agent has to do with each.

## 10.4 Generate the guide

```text
Use the schema-guide skill. Explore the olist schema with the read-only server and write docs/schema-guide.md.
Include a Gotchas section, and prove each gotcha with a query.
```

Check the result against `docs/reference/schema-guide.reference.md`. A good guide includes at least: customer_id is per order (99,441 ids vs 96,096 people), several rows per order in items, payments and reviews, non-unique `review_id`, and no indexes on foreign keys. Anything the agent states without a query behind it should be challenged.
