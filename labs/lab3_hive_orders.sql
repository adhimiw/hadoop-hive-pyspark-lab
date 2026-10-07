-- ============================================================================
-- Lab 3: Hive Aggregation Queries on ORDERS Table
-- ============================================================================
-- Aim: To create an ORDERS table, insert records, and practice aggregate
--      functions including COUNT, SUM, AVG, MIN, MAX, and GROUP BY.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab3_db;
USE lab3_db;

-- --- Step 2: Drop table if it already exists ---
DROP TABLE IF EXISTS ORDERS;

-- --- Step 3: Create the ORDERS table ---
CREATE TABLE ORDERS (
    order_id    INT,
    customer    STRING,
    product     STRING,
    amount      DOUBLE,
    quantity    INT,
    order_date  STRING,
    region      STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 4: Insert 10 records ---
INSERT INTO TABLE ORDERS VALUES (1, 'Ravi', 'Laptop', 999.00, 1, '2023-01-10', 'South');
INSERT INTO TABLE ORDERS VALUES (2, 'Priya', 'Mouse', 25.50, 3, '2023-01-12', 'North');
INSERT INTO TABLE ORDERS VALUES (3, 'Arun', 'Keyboard', 45.00, 2, '2023-02-05', 'East');
INSERT INTO TABLE ORDERS VALUES (4, 'Ravi', 'Monitor', 320.00, 1, '2023-02-10', 'South');
INSERT INTO TABLE ORDERS VALUES (5, 'Sita', 'Laptop', 999.00, 1, '2023-03-01', 'West');
INSERT INTO TABLE ORDERS VALUES (6, 'Priya', 'USB Cable', 10.00, 5, '2023-03-15', 'North');
INSERT INTO TABLE ORDERS VALUES (7, 'Arun', 'Laptop', 999.00, 1, '2023-04-02', 'East');
INSERT INTO TABLE ORDERS VALUES (8, 'Ravi', 'Mouse', 25.50, 2, '2023-04-18', 'South');
INSERT INTO TABLE ORDERS VALUES (9, 'Sita', 'Keyboard', 45.00, 1, '2023-05-20', 'West');
INSERT INTO TABLE ORDERS VALUES (10, 'Amit', 'Monitor', 320.00, 2, '2023-05-25', 'North');

-- --- Step 5: Verify data ---
SELECT * FROM ORDERS;

-- --- Query 1: Total number of orders ---
SELECT COUNT(*) AS total_orders FROM ORDERS;

-- --- Query 2: Total sales amount ---
SELECT SUM(amount * quantity) AS total_sales FROM ORDERS;

-- --- Query 3: Average order amount ---
SELECT AVG(amount) AS avg_amount FROM ORDERS;

-- --- Query 4: Minimum and Maximum order amount ---
SELECT MIN(amount) AS min_amount, MAX(amount) AS max_amount FROM ORDERS;

-- --- Query 5: Total sales per customer (GROUP BY customer) ---
SELECT customer, SUM(amount * quantity) AS total_spent
FROM ORDERS
GROUP BY customer
ORDER BY total_spent DESC;

-- --- Query 6: Number of orders per region ---
SELECT region, COUNT(*) AS num_orders
FROM ORDERS
GROUP BY region
ORDER BY num_orders DESC;

-- --- Query 7: Products sold more than once ---
SELECT product, SUM(quantity) AS total_qty
FROM ORDERS
GROUP BY product
HAVING SUM(quantity) > 2;

-- --- Query 8: Customer with the highest total spending ---
SELECT customer, SUM(amount * quantity) AS total_spent
FROM ORDERS
GROUP BY customer
ORDER BY total_spent DESC
LIMIT 1;

-- ============================================================================
-- End of Lab 3
-- ============================================================================
