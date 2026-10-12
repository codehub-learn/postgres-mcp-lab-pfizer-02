-- Load the unmodified CSV files mounted at /dataset (see scripts/fetch-dataset).
SET search_path = olist;
\copy customers FROM '/dataset/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy geolocation FROM '/dataset/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy sellers FROM '/dataset/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy product_category_name_translation FROM '/dataset/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)
\copy products FROM '/dataset/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy orders FROM '/dataset/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_items FROM '/dataset/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_payments FROM '/dataset/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_reviews FROM '/dataset/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true)
