-- Only constraints that the real data satisfies. Rows are never changed.
-- Deliberately NO secondary indexes: the lab adds them in the tuning section.
SET search_path = olist;

ALTER TABLE customers ADD PRIMARY KEY (customer_id);
ALTER TABLE sellers   ADD PRIMARY KEY (seller_id);
ALTER TABLE products  ADD PRIMARY KEY (product_id);
ALTER TABLE orders    ADD PRIMARY KEY (order_id);
ALTER TABLE product_category_name_translation ADD PRIMARY KEY (product_category_name);
ALTER TABLE order_items    ADD PRIMARY KEY (order_id, order_item_id);
ALTER TABLE order_payments ADD PRIMARY KEY (order_id, payment_sequential);
-- review_id is NOT unique in the source data (827 repeats), the pair is.
ALTER TABLE order_reviews  ADD PRIMARY KEY (review_id, order_id);

ALTER TABLE orders         ADD FOREIGN KEY (customer_id) REFERENCES customers (customer_id);
ALTER TABLE order_items    ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_items    ADD FOREIGN KEY (product_id)  REFERENCES products (product_id);
ALTER TABLE order_items    ADD FOREIGN KEY (seller_id)   REFERENCES sellers (seller_id);
ALTER TABLE order_payments ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_reviews  ADD FOREIGN KEY (order_id)    REFERENCES orders (order_id);
-- products.product_category_name -> translation is NOT enforced: 2 categories have no translation row.

ALTER TABLE order_reviews  ADD CONSTRAINT review_score_range CHECK (review_score BETWEEN 1 AND 5);
ALTER TABLE order_items    ADD CONSTRAINT price_nonneg CHECK (price >= 0 AND freight_value >= 0);
ALTER TABLE order_payments ADD CONSTRAINT payment_nonneg CHECK (payment_value >= 0);
ALTER TABLE orders         ADD CONSTRAINT order_status_valid CHECK (order_status IN
  ('created','approved','invoiced','processing','shipped','delivered','unavailable','canceled'));
