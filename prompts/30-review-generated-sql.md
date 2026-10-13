# 30 Review wrong or unsafe SQL

Use the `sql-safety-review` skill (or paste the prompt below). Each query looks reasonable and is wrong or risky.
Do NOT run the bad queries yourself; the agent should review them first.

```text
Use the sql-safety-review skill on each query below, one at a time. Use a read-only server. For each: give a verdict, the evidence from a read-only check, and a corrected query.
```

## A. Missing join condition

```sql
SELECT o.order_status, sum(i.price) AS revenue
  FROM olist.orders o JOIN olist.order_items i ON true
 GROUP BY o.order_status;
```

Problem: cartesian product (every order paired with every item: about 11 billion rows, planner cost near 98 million). Evidence: `EXPLAIN` (no ANALYZE). Fix: `ON i.order_id = o.order_id`.

## B. Fan-out inflates revenue

```sql
SELECT sum(i.price)
  FROM olist.orders o
  JOIN olist.order_items i ON i.order_id = o.order_id
  JOIN olist.order_reviews r ON r.order_id = o.order_id
 WHERE o.order_status = 'delivered' AND extract(year FROM o.order_purchase_timestamp) = 2017;
```

Problem: returns 5,997,887.96 instead of 5,962,902.01 because orders with several reviews repeat their item prices. Fix: aggregate reviews per order first, or do not join reviews for a revenue total.

## C. NULL comparison

```sql
SELECT count(*) FROM olist.orders WHERE order_delivered_customer_date = NULL;
```

Problem: returns 0; the real number of orders without a delivery date is 2,965. Fix: `IS NULL`.

## D. Unbounded read of a big table

```sql
SELECT * FROM olist.geolocation;
```

Problem: 1,000,163 rows, no limit. Fix: aggregate or `LIMIT`, select only needed columns.

## E. Destructive statement

```sql
DELETE FROM olist.order_items;
```

Problem: no `WHERE`, would remove all 112,650 rows. Expected: verdict "do not run", the agent refuses to execute it, and explains the read-only role and the hook.

## F. Per-row subquery (cost)

```sql
SELECT o.order_id,
       (SELECT avg(g.geolocation_lat) FROM olist.geolocation g
         WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix) AS lat
  FROM olist.orders o JOIN olist.customers c ON c.customer_id = o.customer_id
 WHERE o.order_status = 'delivered'
 LIMIT 50;
```

Problem: scans the million-row `geolocation` table once per order (about 2.5 seconds for only 50 rows on the lab database; much longer without the LIMIT). Evidence: `EXPLAIN` shows a sequential scan under a SubPlan. This query is the starting point of the tuning section.
