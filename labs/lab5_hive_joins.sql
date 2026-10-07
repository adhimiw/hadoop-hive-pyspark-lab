-- ============================================================================
-- Lab 5: Hive Join Operations (5 Tables)
-- ============================================================================
-- Aim: To practice INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN, and
--      cross joins across multiple tables: DEPARTMENT, EMPLOYEES, LOCATION,
--      GRADE, and JOB.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab5_db;
USE lab5_db;

-- --- Step 2: Drop tables if they already exist ---
DROP TABLE IF EXISTS DEPARTMENT;
DROP TABLE IF EXISTS EMPLOYEES;
DROP TABLE IF EXISTS LOCATION;
DROP TABLE IF EXISTS GRADE;
DROP TABLE IF EXISTS JOB;

-- --- Step 3: Create DEPARTMENT table ---
CREATE TABLE DEPARTMENT (
    dept_id     INT,
    dept_name   STRING,
    location_id INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 4: Create EMPLOYEES table ---
CREATE TABLE EMPLOYEES (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    dept_id     INT,
    job_id      INT,
    manager_id  INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 5: Create LOCATION table ---
CREATE TABLE LOCATION (
    location_id     INT,
    city            STRING,
    state           STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 6: Create GRADE table ---
CREATE TABLE GRADE (
    grade_id    INT,
    min_salary  DOUBLE,
    max_salary  DOUBLE,
    grade_name  STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 7: Create JOB table ---
CREATE TABLE JOB (
    job_id      INT,
    job_title   STRING,
    min_salary  DOUBLE,
    max_salary  DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 8: Insert data into DEPARTMENT ---
INSERT INTO TABLE DEPARTMENT VALUES (10, 'HR', 1001);
INSERT INTO TABLE DEPARTMENT VALUES (20, 'IT', 1002);
INSERT INTO TABLE DEPARTMENT VALUES (30, 'Finance', 1003);
INSERT INTO TABLE DEPARTMENT VALUES (40, 'Marketing', 1004);

-- --- Step 9: Insert data into EMPLOYEES ---
INSERT INTO TABLE EMPLOYEES VALUES (101, 'Alice', 55000, 10, 1, NULL);
INSERT INTO TABLE EMPLOYEES VALUES (102, 'Bob', 62000, 20, 2, 101);
INSERT INTO TABLE EMPLOYEES VALUES (103, 'Charlie', 48000, 30, 3, 101);
INSERT INTO TABLE EMPLOYEES VALUES (104, 'Diana', 71000, 20, 4, 102);
INSERT INTO TABLE EMPLOYEES VALUES (105, 'Eve', 53000, 10, 1, 101);
INSERT INTO TABLE EMPLOYEES VALUES (106, 'Frank', 67000, 30, 3, 103);
INSERT INTO TABLE EMPLOYEES VALUES (107, 'Grace', 58000, 20, 2, 104);
INSERT INTO TABLE EMPLOYEES VALUES (108, 'Henry', 45000, 10, 1, 105);
INSERT INTO TABLE EMPLOYEES VALUES (109, 'Ivy', 73000, 30, 4, 106);
INSERT INTO EMPLOYEES VALUES (110, 'Jack', 61000, 20, 2, 107);

-- --- Step 10: Insert data into LOCATION ---
INSERT INTO TABLE LOCATION VALUES (1001, 'Chennai', 'Tamil Nadu');
INSERT INTO TABLE LOCATION VALUES (1002, 'Bangalore', 'Karnataka');
INSERT INTO TABLE LOCATION VALUES (1003, 'Mumbai', 'Maharashtra');
INSERT INTO TABLE LOCATION VALUES (1004, 'Delhi', 'Delhi');

-- --- Step 11: Insert data into GRADE ---
INSERT INTO TABLE GRADE VALUES (1, 40000, 55000, 'Grade A');
INSERT INTO TABLE GRADE VALUES (2, 55001, 65000, 'Grade B');
INSERT INTO TABLE GRADE VALUES (3, 65001, 75000, 'Grade C');

-- --- Step 12: Insert data into JOB ---
INSERT INTO TABLE JOB VALUES (1, 'Analyst', 40000, 60000);
INSERT INTO TABLE JOB VALUES (2, 'Developer', 55000, 80000);
INSERT INTO TABLE JOB VALUES (3, 'Accountant', 45000, 70000);
INSERT INTO TABLE JOB VALUES (4, 'Manager', 65000, 90000);

-- --- Verify all tables ---
SELECT * FROM DEPARTMENT;
SELECT * FROM EMPLOYEES;
SELECT * FROM LOCATION;
SELECT * FROM GRADE;
SELECT * FROM JOB;

-- =========================================================================
-- JOIN QUERIES
-- =========================================================================

-- --- Query 1: INNER JOIN - Employees with their Department names ---
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name
FROM EMPLOYEES e
INNER JOIN DEPARTMENT d ON e.dept_id = d.dept_id;

-- --- Query 2: INNER JOIN - Employees with their Job titles ---
SELECT e.emp_id, e.emp_name, j.job_title
FROM EMPLOYEES e
INNER JOIN JOB j ON e.job_id = j.job_id;

-- --- Query 3: INNER JOIN - Department with Location ---
SELECT d.dept_name, l.city, l.state
FROM DEPARTMENT d
INNER JOIN LOCATION l ON d.location_id = l.location_id;

-- --- Query 4: LEFT JOIN - All employees with department (include employees without dept) ---
SELECT e.emp_id, e.emp_name, d.dept_name
FROM EMPLOYEES e
LEFT JOIN DEPARTMENT d ON e.dept_id = d.dept_id;

-- --- Query 5: RIGHT JOIN - All departments with employees ---
SELECT d.dept_name, e.emp_name
FROM EMPLOYEES e
RIGHT JOIN DEPARTMENT d ON e.dept_id = d.dept_id;

-- --- Query 6: FULL OUTER JOIN - All employees and all departments ---
SELECT e.emp_name, d.dept_name
FROM EMPLOYEES e
FULL OUTER JOIN DEPARTMENT d ON e.dept_id = d.dept_id;

-- --- Query 7: 3-table JOIN - Employees with Department and Location ---
SELECT e.emp_name, d.dept_name, l.city, l.state
FROM EMPLOYEES e
INNER JOIN DEPARTMENT d ON e.dept_id = d.dept_id
INNER JOIN LOCATION l ON d.location_id = l.location_id;

-- --- Query 8: Employee with their Manager (self join) ---
SELECT
    e.emp_name AS employee,
    m.emp_name AS manager
FROM EMPLOYEES e
LEFT JOIN EMPLOYEES m ON e.manager_id = m.emp_id;

-- --- Query 9: Employees with their Grade ---
SELECT e.emp_name, e.salary, g.grade_name
FROM EMPLOYEES e
INNER JOIN GRADE g ON e.salary BETWEEN g.min_salary AND g.max_salary
ORDER BY e.salary;

-- --- Query 10: Employees earning above their job's average salary ---
SELECT e.emp_name, e.salary, j.job_title
FROM EMPLOYEES e
INNER JOIN JOB j ON e.job_id = j.job_id
WHERE e.salary > (j.min_salary + j.max_salary) / 2;

-- --- Query 11: Count employees per department with dept name ---
SELECT d.dept_name, COUNT(e.emp_id) AS emp_count
FROM DEPARTMENT d
LEFT JOIN EMPLOYEES e ON d.dept_id = e.dept_id
GROUP BY d.dept_name;

-- --- Query 12: Department-wise total salary ---
SELECT d.dept_name, SUM(e.salary) AS total_salary, AVG(e.salary) AS avg_salary
FROM DEPARTMENT d
INNER JOIN EMPLOYEES e ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY total_salary DESC;

-- --- Query 13: City-wise employee count ---
SELECT l.city, l.state, COUNT(e.emp_id) AS emp_count
FROM LOCATION l
LEFT JOIN DEPARTMENT d ON l.location_id = d.location_id
LEFT JOIN EMPLOYEES e ON d.dept_id = e.dept_id
GROUP BY l.city, l.state;

-- --- Query 14: Employees in each grade with count ---
SELECT g.grade_name, COUNT(e.emp_id) AS emp_count,
       MIN(e.salary) AS min_sal, MAX(e.salary) AS max_sal
FROM GRADE g
LEFT JOIN EMPLOYEES e ON e.salary BETWEEN g.min_salary AND g.max_salary
GROUP BY g.grade_name;

-- ============================================================================
-- End of Lab 5
-- ============================================================================
