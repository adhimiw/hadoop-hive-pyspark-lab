-- ============================================================================
-- Lab 4: Hive String and Date Functions
-- ============================================================================
-- Aim: To practice Hive built-in string functions (REGEXP_REPLACE, LENGTH,
--      CONCAT, UPPER, LOWER, SUBSTR, TRIM, etc.) and date functions
--      (YEAR, MONTH, DAY, DATEDIFF, DATE_FORMAT, etc.) on an EMPLOYEES table.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab4_db;
USE lab4_db;

-- --- Step 2: Drop table if it already exists ---
DROP TABLE IF EXISTS EMPLOYEES;

-- --- Step 3: Create EMPLOYEES table ---
CREATE TABLE EMPLOYEES (
    emp_id      INT,
    first_name  STRING,
    last_name   STRING,
    email       STRING,
    salary      DOUBLE,
    hire_date   STRING,
    department  STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 4: Insert 10 records ---
INSERT INTO TABLE EMPLOYEES VALUES (1, 'John', 'Smith', 'john.smith@company.com', 55000, '2019-03-15', 'HR');
INSERT INTO TABLE EMPLOYEES VALUES (2, 'Jane', 'Doe', 'jane.doe@company.com', 62000, '2018-07-20', 'IT');
INSERT INTO TABLE EMPLOYEES VALUES (3, 'Bob', 'Williams', 'bob.williams@company.com', 48000, '2020-01-10', 'Finance');
INSERT INTO TABLE EMPLOYEES VALUES (4, 'Alice', 'Brown', 'alice.brown@company.com', 71000, '2017-11-05', 'IT');
INSERT INTO TABLE EMPLOYEES VALUES (5, 'Eve', 'Davis', 'eve.davis@company.com', 53000, '2021-06-25', 'HR');
INSERT INTO TABLE EMPLOYEES VALUES (6, 'Frank', 'Miller', 'frank.miller@company.com', 67000, '2016-09-12', 'Finance');
INSERT INTO TABLE EMPLOYEES VALUES (7, 'Grace', 'Wilson', 'grace.wilson@company.com', 58000, '2019-08-30', 'IT');
INSERT INTO TABLE EMPLOYEES VALUES (8, 'Henry', 'Moore', 'henry.moore@company.com', 45000, '2022-02-14', 'HR');
INSERT INTO TABLE EMPLOYEES VALUES (9, 'Ivy', 'Taylor', 'ivy.taylor@company.com', 73000, '2015-05-18', 'Finance');
INSERT INTO TABLE EMPLOYEES VALUES (10, 'Jack', 'Anderson', 'jack.anderson@company.com', 61000, '2020-12-01', 'IT');

-- --- Step 5: Verify data ---
SELECT * FROM EMPLOYEES;

-- --- Query 1: String Functions ---
-- Upper, Lower, Concat
SELECT
    first_name,
    UPPER(first_name) AS upper_name,
    LOWER(last_name) AS lower_last,
    CONCAT(first_name, ' ', last_name) AS full_name
FROM EMPLOYEES;

-- --- Query 2: Length and Substring ---
SELECT
    first_name,
    LENGTH(first_name) AS name_length,
    SUBSTR(first_name, 1, 3) AS first_3_chars
FROM EMPLOYEES;

-- --- Query 3: Trim, Ltrim, Rtrim ---
SELECT
    TRIM('  Hello  ') AS trimmed,
    LTRIM('  Hello  ') AS left_trimmed,
    RTRIM('  Hello  ') AS right_trimmed;

-- --- Query 4: REGEXP_REPLACE to extract username from email ---
SELECT
    first_name,
    email,
    REGEXP_REPLACE(email, '@company.com', '') AS username
FROM EMPLOYEES;

-- --- Query 5: REGEXP_REPLACE to remove spaces and special characters ---
SELECT
    REGEXP_REPLACE('Hello  World   2023', ' +', ' ') AS cleaned_spaces,
    REGEXP_REPLACE('abc123def456', '[0-9]', '') AS no_numbers;

-- --- Query 6: INITCAP (capitalize first letter of each word) ---
SELECT
    CONCAT(UPPER(SUBSTR(first_name, 1, 1)), LOWER(SUBSTR(first_name, 2))) AS initcap_name
FROM EMPLOYEES;

-- --- Query 7: Date Functions ---
SELECT
    first_name,
    hire_date,
    YEAR(hire_date) AS hire_year,
    MONTH(hire_date) AS hire_month,
    DAY(hire_date) AS hire_day
FROM EMPLOYEES;

-- --- Query 8: DATEDIFF - years of service ---
SELECT
    first_name,
    hire_date,
    DATEDIFF(CURRENT_DATE, hire_date) AS days_employed,
    ROUND(DATEDIFF(CURRENT_DATE, hire_date) / 365.25, 1) AS years_employed
FROM EMPLOYEES;

-- --- Query 9: DATE_FORMAT ---
SELECT
    first_name,
    hire_date,
    DATE_FORMAT(hire_date, 'yyyy-MM') AS year_month,
    DATE_FORMAT(hire_date, 'dd/MM/yyyy') AS formatted_date
FROM EMPLOYEES;

-- --- Query 10: Employees hired before 2019 ---
SELECT first_name, hire_date
FROM EMPLOYEES
WHERE YEAR(hire_date) < 2019;

-- ============================================================================
-- End of Lab 4
-- ============================================================================
