-- ============================================================================
-- Lab 2: Hive DDL and DML Operations on EMPLOYEE Table
-- ============================================================================
-- Aim: To create a Hive managed table EMPLOYEE, insert records using DML
--      commands, and perform basic SELECT queries.
--
-- Prerequisites:
--   - HiveServer2 running (port 10000)
--   - Beeline connected: beeline -u jdbc:hive2://localhost:10000
--   - Or Hive CLI: hive
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Show existing databases ---
SHOW DATABASES;

-- --- Step 2: Create a new database for lab exercises ---
CREATE DATABASE IF NOT EXISTS lab2_db;
USE lab2_db;

-- --- Step 3: Drop table if it already exists (for re-runs) ---
DROP TABLE IF EXISTS EMPLOYEE;

-- --- Step 4: Create the EMPLOYEE table ---
CREATE TABLE EMPLOYEE (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    dept_name   STRING,
    doj         STRING,
    gender      STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 5: Describe the table structure ---
DESCRIBE EMPLOYEE;
DESC FORMATTED EMPLOYEE;

-- --- Step 6: Insert records one by one using VALUES ---
INSERT INTO TABLE EMPLOYEE VALUES (101, 'Alice', 55000, 'HR', '2019-03-15', 'F');
INSERT INTO TABLE EMPLOYEE VALUES (102, 'Bob', 62000, 'IT', '2018-07-20', 'M');
INSERT INTO TABLE EMPLOYEE VALUES (103, 'Charlie', 48000, 'Finance', '2020-01-10', 'M');
INSERT INTO TABLE EMPLOYEE VALUES (104, 'Diana', 71000, 'IT', '2017-11-05', 'F');
INSERT INTO TABLE EMPLOYEE VALUES (105, 'Eve', 53000, 'HR', '2021-06-25', 'F');
INSERT INTO TABLE EMPLOYEE VALUES (106, 'Frank', 67000, 'Finance', '2016-09-12', 'M');
INSERT INTO TABLE EMPLOYEE VALUES (107, 'Grace', 58000, 'IT', '2019-08-30', 'F');
INSERT INTO TABLE EMPLOYEE VALUES (108, 'Henry', 45000, 'HR', '2022-02-14', 'M');
INSERT INTO TABLE EMPLOYEE VALUES (109, 'Ivy', 73000, 'Finance', '2015-05-18', 'F');
INSERT INTO TABLE EMPLOYEE VALUES (110, 'Jack', 61000, 'IT', '2020-12-01', 'M');

-- --- Step 7: Verify the data ---
SELECT * FROM EMPLOYEE;

-- --- Step 8: Select specific columns ---
SELECT emp_name, salary FROM EMPLOYEE;

-- --- Step 9: Query with WHERE clause ---
SELECT emp_name, dept_name, salary
FROM EMPLOYEE
WHERE salary > 55000;

-- --- Step 10: Query with ORDER BY ---
SELECT emp_name, salary
FROM EMPLOYEE
ORDER BY salary DESC;

-- ============================================================================
-- End of Lab 2
-- ============================================================================
