-- ============================================================================
-- Lab 6: Hive Aggregate Functions on ORDER_TABLE
-- ============================================================================
-- Aim: To create an ORDER_TABLE and practice aggregate functions including
--      COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING, and window-like analytics.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab6_db;
USE lab6_db;

-- --- Step 2: Drop table if it already exists ---
DROP TABLE IF EXISTS ORDER_TABLE;

-- --- Step 3: Create ORDER_TABLE ---
CREATE TABLE ORDER_TABLE (
    order_id        INT,
    customer_name   STRING,
    product_name    STRING,
    quantity        INT,
    unit_price      DOUBLE,
    order_date      STRING,
    payment_mode    STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 4: Insert 10 records ---
INSERT INTO TABLE ORDER_TABLE VALUES (101, 'Rohan', 'Laptop', 1, 999.00, '2023-01-05', 'Credit Card');
INSERT INTO TABLE ORDER_TABLE VALUES (102, 'Meena', 'Mouse', 3, 25.50, '2023-01-10', 'Cash');
INSERT INTO TABLE ORDER_TABLE VALUES (103, 'Kiran', 'Keyboard', 2, 45.00, '2023-02-14', 'UPI');
INSERT INTO TABLE ORDER_TABLE VALUES (104, 'Rohan', 'Monitor', 1, 320.00, '2023-02-20', 'Credit Card');
INSERT INTO TABLE ORDER_TABLE VALUES (105, 'Asha', 'Laptop', 1, 999.00, '2023-03-01', 'Debit Card');
INSERT INTO TABLE ORDER_TABLE VALUES (106, 'Meena', 'USB Hub', 5, 12.00, '2023-03-15', 'Cash');
INSERT INTO TABLE ORDER_TABLE VALUES (107, 'Kiran', 'Laptop', 1, 999.00, '2023-04-02', 'Credit Card');
INSERT INTO TABLE ORDER_TABLE VALUES (108, 'Rohan', 'Mouse', 2, 25.50, '2023-04-18', 'UPI');
INSERT INTO TABLE ORDER_TABLE VALUES (109, 'Asha', 'Keyboard', 1, 45.00, '2023-05-10', 'Credit Card');
INSERT INTO TABLE ORDER_TABLE VALUES (110, 'Deepak', 'Monitor', 2, 320.00, '2023-05-25', 'Debit Card');

-- --- Step 5: Verify data ---
SELECT * FROM ORDER_TABLE;

-- --- Query 1: Total number of orders ---
SELECT COUNT(*) AS total_orders FROM ORDER_TABLE;

-- --- Query 2: Total revenue (quantity * unit_price) ---
SELECT ROUND(SUM(quantity * unit_price), 2) AS total_revenue FROM ORDER_TABLE;

-- --- Query 3: Average order value ---
SELECT ROUND(AVG(quantity * unit_price), 2) AS avg_order_value FROM ORDER_TABLE;

-- --- Query 4: Cheapest and most expensive product ordered ---
SELECT MIN(unit_price) AS cheapest, MAX(unit_price) AS most_expensive FROM ORDER_TABLE;

-- --- Query 5: Customer-wise total spending ---
SELECT customer_name, ROUND(SUM(quantity * unit_price), 2) AS total_spent
FROM ORDER_TABLE
GROUP BY customer_name
ORDER BY total_spent DESC;

-- --- Query 6: Product-wise total quantity sold ---
SELECT product_name, SUM(quantity) AS total_qty_sold
FROM ORDER_TABLE
GROUP BY product_name
ORDER BY total_qty_sold DESC;

-- --- Query 7: Payment mode usage count ---
SELECT payment_mode, COUNT(*) AS order_count
FROM ORDER_TABLE
GROUP BY payment_mode
ORDER BY order_count DESC;

-- --- Query 8: Monthly revenue ---
SELECT
    SUBSTR(order_date, 1, 7) AS order_month,
    ROUND(SUM(quantity * unit_price), 2) AS monthly_revenue
FROM ORDER_TABLE
GROUP BY SUBSTR(order_date, 1, 7)
ORDER BY order_month;

-- ============================================================================
-- End of Lab 6
-- ============================================================================
