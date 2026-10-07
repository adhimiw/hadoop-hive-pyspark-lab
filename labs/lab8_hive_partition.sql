-- ============================================================================
-- Lab 8: Hive Dynamic Partitioning
-- ============================================================================
-- Aim: To understand and implement dynamic partitioning in Hive using an
--      EMPLOYEES_PART table partitioned by department, and compare partitioned
--      vs non-partitioned table storage in HDFS.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--   - Hive dynamic partitioning enabled (set hive.exec.dynamic.partition=true)
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab8_db;
USE lab8_db;

-- --- Step 2: Drop table if it already exists ---
DROP TABLE IF EXISTS EMPLOYEES_SRC;
DROP TABLE IF EXISTS EMPLOYEES_PART;

-- --- Step 3: Enable dynamic partitioning ---
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=1000;
SET hive.exec.max.dynamic.partitions.pernode=100;

-- --- Step 4: Create a source (non-partitioned) table to load data ---
CREATE TABLE EMPLOYEES_SRC (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    dept_name   STRING,
    gender      STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 5: Create the partitioned target table ---
CREATE TABLE EMPLOYEES_PART (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    gender      STRING
)
PARTITIONED BY (dept_name STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 6: Insert data into source table ---
INSERT INTO TABLE EMPLOYEES_SRC VALUES (101, 'Alice', 55000, 'HR', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (102, 'Bob', 62000, 'IT', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (103, 'Charlie', 48000, 'Finance', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (104, 'Diana', 71000, 'IT', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (105, 'Eve', 53000, 'HR', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (106, 'Frank', 67000, 'Finance', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (107, 'Grace', 58000, 'IT', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (108, 'Henry', 45000, 'HR', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (109, 'Ivy', 73000, 'Finance', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (110, 'Jack', 61000, 'IT', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (111, 'Kelly', 49000, 'HR', 'F');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (112, 'Liam', 72000, 'Finance', 'M');

-- --- Step 7: Verify source data ---
SELECT * FROM EMPLOYEES_SRC;

-- --- Step 8: Dynamic partition INSERT ---
INSERT OVERWRITE TABLE EMPLOYEES_PART PARTITION (dept_name)
SELECT emp_id, emp_name, salary, gender, dept_name
FROM EMPLOYEES_SRC;

-- --- Step 9: Verify partitioned table ---
SELECT * FROM EMPLOYEES_PART;

-- --- Step 10: Show partitions ---
SHOW PARTITIONS EMPLOYEES_PART;

-- --- Step 11: Query data from a specific partition ---
SELECT * FROM EMPLOYEES_PART WHERE dept_name = 'IT';

-- --- Step 12: Query data from multiple partitions ---
SELECT * FROM EMPLOYEES_PART WHERE dept_name IN ('HR', 'Finance');

-- --- Step 13: Partition-wise aggregation ---
SELECT dept_name, COUNT(*) AS emp_count, ROUND(AVG(salary), 2) AS avg_salary
FROM EMPLOYEES_PART
GROUP BY dept_name
ORDER BY avg_salary DESC;

-- --- Step 14: Compare storage in HDFS ---
-- Non-partitioned table:
--   /user/hive/warehouse/lab8_db.db/employees_src/000000_0
--
-- Partitioned table:
--   /user/hive/warehouse/lab8_db.db/employees_part/dept_name=HR/000000_0
--   /user/hive/warehouse/lab8_db.db/employees_part/dept_name=IT/000000_0
--   /user/hive/warehouse/lab8_db.db/employees_part/dept_name=Finance/000000_0

-- You can verify via HDFS CLI:
-- hdfs dfs -ls /user/hive/warehouse/lab8_db.db/employees_src/
-- hdfs dfs -ls /user/hive/warehouse/lab8_db.db/employees_part/
-- hdfs dfs -ls /user/hive/warehouse/lab8_db.db/employees_part/dept_name=IT/

-- --- Step 15: Add a new department and verify dynamic partition creation ---
INSERT INTO TABLE EMPLOYEES_SRC VALUES (113, 'Mike', 65000, 'Marketing', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (114, 'Nina', 59000, 'Marketing', 'F');

INSERT INTO TABLE EMPLOYEES_PART PARTITION (dept_name)
SELECT emp_id, emp_name, salary, gender, dept_name
FROM EMPLOYEES_SRC
WHERE dept_name = 'Marketing';

-- Verify the new partition was dynamically created ---
SHOW PARTITIONS EMPLOYEES_PART;
SELECT * FROM EMPLOYEES_PART WHERE dept_name = 'Marketing';

-- --- Step 16: Drop a specific partition ---
ALTER TABLE EMPLOYEES_PART DROP PARTITION (dept_name='Marketing');
SHOW PARTITIONS EMPLOYEES_PART;

-- --- Step 17: Describe the partitioned table ---
DESC FORMATTED EMPLOYEES_PART;

-- ============================================================================
-- End of Lab 8
-- ============================================================================
