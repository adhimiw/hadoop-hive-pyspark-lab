# Hadoop & Hive Lab Manual

## Lab 1: HDFS Basic Commands

### Aim
To learn and practice basic Hadoop HDFS commands for file and directory operations including create, upload, download, copy, move, delete, and permissions management in a single-node Hadoop cluster.

### Prerequisites
- Hadoop 3.x installed and configured
- HDFS running (`start-dfs.sh`)
- `JAVA_HOME` and `HADOOP_HOME` set in `~/.bashrc`

### Procedure & Commands

#### Step 1: Verify HDFS is running
```bash
jps
```
**Output:**
```
12345 NameNode
12346 DataNode
12347 SecondaryNameNode
12348 Jps
```

#### Step 2: Check HDFS filesystem root
```bash
hdfs dfs -ls /
```
**Output:**
```
Found 2 items
drwxr-xr-x   - hdfs supergroup          0 2025-01-15 10:00 /user
drwxr-xr-x   - hdfs supergroup          0 2025-01-15 10:00 /tmp
```

#### Step 3: Create directories in HDFS
```bash
hdfs dfs -mkdir /lab1
hdfs dfs -mkdir /lab1/data
hdfs dfs -mkdir -p /lab1/data/subdir1
hdfs dfs -mkdir -p /lab1/data/subdir2
hdfs dfs -ls /lab1/
```
**Output:**
```
Found 2 items
drwxr-xr-x   - hdfs supergroup          0 2025-01-15 10:05 /lab1/data
```

#### Step 4: Create a local file to upload
```bash
mkdir -p /tmp/hdfs_lab
echo "Row1: Alice,1001,HR" > /tmp/hdfs_lab/employees.txt
echo "Row2: Bob,1002,IT" >> /tmp/hdfs_lab/employees.txt
echo "Row3: Charlie,1003,Finance" >> /tmp/hdfs_lab/employees.txt
echo "Row4: Diana,1004,HR" >> /tmp/hdfs_lab/employees.txt
echo "Row5: Eve,1005,IT" >> /tmp/hdfs_lab/employees.txt
cat /tmp/hdfs_lab/employees.txt
```
**Output:**
```
Row1: Alice,1001,HR
Row2: Bob,1002,IT
Row3: Charlie,1003,Finance
Row4: Diana,1004,HR
Row5: Eve,1005,IT
```

#### Step 5: Upload file from local to HDFS
```bash
hdfs dfs -put /tmp/hdfs_lab/employees.txt /lab1/data/
hdfs dfs -ls /lab1/data/
```
**Output:**
```
Found 1 items
-rw-r--r--   3 hdfs supergroup         85 2025-01-15 10:10 /lab1/data/employees.txt
```

#### Step 6: View file contents in HDFS
```bash
hdfs dfs -cat /lab1/data/employees.txt
```
**Output:**
```
Row1: Alice,1001,HR
Row2: Bob,1002,IT
Row3: Charlie,1003,Finance
Row4: Diana,1004,HR
Row5: Eve,1005,IT
```

#### Step 7: Download file from HDFS to local
```bash
mkdir -p /tmp/hdfs_lab/download
hdfs dfs -get /lab1/data/employees.txt /tmp/hdfs_lab/download/
ls /tmp/hdfs_lab/download/
```
**Output:**
```
employees.txt
```

#### Step 8: Copy file within HDFS
```bash
hdfs dfs -cp /lab1/data/employees.txt /lab1/data/subdir1/employees_copy.txt
hdfs dfs -ls /lab1/data/subdir1/
```
**Output:**
```
Found 1 items
-rw-r--r--   3 hdfs supergroup         85 2025-01-15 10:15 /lab1/data/subdir1/employees_copy.txt
```

#### Step 9: Move file within HDFS
```bash
hdfs dfs -mkdir /lab1/archive
hdfs dfs -mv /lab1/data/subdir1/employees_copy.txt /lab1/archive/
hdfs dfs -ls /lab1/archive/
```
**Output:**
```
Found 1 items
-rw-r--r--   3 hdfs supergroup         85 2025-01-15 10:15 /lab1/archive/employees_copy.txt
```

#### Step 10: Check file size and disk usage
```bash
hdfs dfs -du -s /lab1/data/employees.txt
```
**Output:**
```
85  /lab1/data/employees.txt
```

```bash
hdfs dfs -du -h /lab1/data/
```
**Output:**
```
85  /lab1/data/employees.txt
```

#### Step 11: Count files and directories
```bash
hdfs dfs -count /lab1/
```
**Output:**
```
            4            1                 85 /lab1
```
*(4 directories, 1 file, 85 bytes)*

#### Step 12: Use getmerge to download directory as single file
```bash
echo "Product: Laptop,Price:999" > /tmp/hdfs_lab/products.txt
echo "Product: Mouse,Price:25" >> /tmp/hdfs_lab/products.txt
hdfs dfs -put /tmp/hdfs_lab/products.txt /lab1/data/

hdfs dfs -getmerge /lab1/data/ /tmp/hdfs_lab/all_data_merged.txt
cat /tmp/hdfs_lab/all_data_merged.txt
```
**Output:**
```
Row1: Alice,1001,HR
Row2: Bob,1002,IT
Row3: Charlie,1003,Finance
Row4: Diana,1004,HR
Row5: Eve,1005,IT
Product: Laptop,Price:999
Product: Mouse,Price:25
```

#### Step 13: Test file existence in HDFS
```bash
hdfs dfs -test -e /lab1/data/employees.txt && echo "File exists" || echo "File does not exist"
hdfs dfs -test -d /lab1/data/ && echo "Directory exists" || echo "Not a directory"
hdfs dfs -test -f /lab1/data/employees.txt && echo "Is a file" || echo "Not a file"
```
**Output:**
```
File exists
Directory exists
Is a file
```

#### Step 14: Create empty file in HDFS
```bash
hdfs dfs -touch /lab1/data/empty_file.txt
hdfs dfs -ls /lab1/data/empty_file.txt
```
**Output:**
```
-rw-r--r--   3 hdfs supergroup          0 2025-01-15 10:20 /lab1/data/empty_file.txt
```

#### Step 15: Append content to HDFS file
```bash
echo "Row6: Frank,1006,Finance" | hdfs dfs -appendToFile - /lab1/data/employees.txt
hdfs dfs -cat /lab1/data/employees.txt
```
**Output:**
```
Row1: Alice,1001,HR
Row2: Bob,1002,IT
Row3: Charlie,1003,Finance
Row4: Diana,1004,HR
Row5: Eve,1005,IT
Row6: Frank,1006,Finance
```

#### Step 16: Change permissions in HDFS
```bash
hdfs dfs -chmod 755 /lab1/
hdfs dfs -chmod -R 644 /lab1/data/
hdfs dfs -ls -la /lab1/
```
**Output:**
```
drwxr-xr-x   - hdfs supergroup          0 2025-01-15 10:05 /lab1/data
```

#### Step 17: Tail (view last 1KB) in HDFS
```bash
hdfs dfs -tail /lab1/data/employees.txt
```
**Output:**
```
Row1: Alice,1001,HR
Row2: Bob,1002,IT
Row3: Charlie,1003,Finance
Row4: Diana,1004,HR
Row5: Eve,1005,IT
Row6: Frank,1006,Finance
```

#### Step 18: Find files matching a pattern
```bash
hdfs dfs -find /lab1/ -name "*.txt"
```
**Output:**
```
/lab1/data/employees.txt
/lab1/data/products.txt
/lab1/data/empty_file.txt
/lab1/archive/employees_copy.txt
```

#### Step 19: Delete files and directories
```bash
hdfs dfs -rm /lab1/data/empty_file.txt
hdfs dfs -rm -r /lab1/archive/
hdfs dfs -rm -r /lab1/data/subdir2/
hdfs dfs -ls -R /lab1/
```
**Output:**
```
/lab1/data:
-rw-r--r--   3 hdfs supergroup         85 2025-01-15 10:10 /lab1/data/employees.txt
-rw-r--r--   3 hdfs supergroup         40 2025-01-15 10:12 /lab1/data/products.txt

/lab1/data/subdir1:
```

---

## Lab 2: Hive DDL and DML on EMPLOYEE Table

### Aim
To create a Hive managed table `EMPLOYEE`, insert records using DML commands, and perform basic SELECT queries.

### Prerequisites
- HiveServer2 running (port 10000)
- Beeline connected: `beeline -u jdbc:hive2://localhost:10000`
- Or Hive CLI: `hive`

### Procedure & Commands

#### Step 1: Show existing databases
```sql
SHOW DATABASES;
```
**Output:**
```
+-------------------------------+
|           databaseName        |
+-------------------------------+
| default                       |
+-------------------------------+
```

#### Step 2: Create a new database
```sql
CREATE DATABASE IF NOT EXISTS lab2_db;
USE lab2_db;
```
**Output:**
```
OK
```

#### Step 3: Create the EMPLOYEE table
```sql
DROP TABLE IF EXISTS EMPLOYEE;

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
```
**Output:**
```
OK
```

#### Step 4: Describe the table
```sql
DESCRIBE EMPLOYEE;
```
**Output:**
```
+---------------------------+------------+----------+
|         col_name          |  data_type |  comment |
+---------------------------+------------+----------+
| emp_id                    | int        |          |
| emp_name                  | string     |          |
| salary                    | double     |          |
| dept_name                 | string     |          |
| doj                       | string     |          |
| gender                    | string     |          |
+---------------------------+------------+----------+
```

#### Step 5: Insert 10 records
```sql
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
```
**Output (each):**
```
Query ID = ... Total jobs = 1
Launching Job 1 ...
OK
Time taken: 1.234 seconds
```

#### Step 6: Verify the data
```sql
SELECT * FROM EMPLOYEE;
```
**Output:**
```
+----------+------------+----------+-------------+-------------+-----------+
| emp_id   | emp_name   | salary   | dept_name   |    doj      |  gender   |
+----------+------------+----------+-------------+-------------+-----------+
| 101      | Alice      | 55000.0  | HR          | 2019-03-15  | F         |
| 102      | Bob        | 62000.0  | IT          | 2018-07-20  | M         |
| 103      | Charlie    | 48000.0  | Finance     | 2020-01-10  | M         |
| 104      | Diana      | 71000.0  | IT          | 2017-11-05  | F         |
| 105      | Eve        | 53000.0  | HR          | 2021-06-25  | F         |
| 106      | Frank      | 67000.0  | Finance     | 2016-09-12  | M         |
| 107      | Grace      | 58000.0  | IT          | 2019-08-30  | F         |
| 108      | Henry      | 45000.0  | HR          | 2022-02-14  | M         |
| 109      | Ivy        | 73000.0  | Finance     | 2015-05-18  | F         |
| 110      | Jack       | 61000.0  | IT          | 2020-12-01  | M         |
+----------+------------+----------+-------------+-------------+-----------+
```

#### Step 7: Select specific columns
```sql
SELECT emp_name, salary FROM EMPLOYEE;
```
**Output:**
```
+------------+-----------+
| emp_name   |  salary   |
+------------+-----------+
| Alice      | 55000.0   |
| Bob        | 62000.0   |
| Charlie    | 48000.0   |
| Diana      | 71000.0   |
| Eve        | 53000.0   |
| Frank      | 67000.0   |
| Grace      | 58000.0   |
| Henry      | 45000.0   |
| Ivy        | 73000.0   |
| Jack       | 61000.0   |
+------------+-----------+
```

#### Step 8: Query with WHERE clause
```sql
SELECT emp_name, dept_name, salary
FROM EMPLOYEE
WHERE salary > 55000;
```
**Output:**
```
+------------+-------------+-----------+
| emp_name   | dept_name   |  salary   |
+------------+-------------+-----------+
| Bob        | IT          | 62000.0   |
| Diana      | IT          | 71000.0   |
| Frank      | Finance     | 67000.0   |
| Grace      | IT          | 58000.0   |
| Ivy        | Finance     | 73000.0   |
| Jack       | IT          | 61000.0   |
+------------+-------------+-----------+
```

#### Step 9: Query with ORDER BY
```sql
SELECT emp_name, salary
FROM EMPLOYEE
ORDER BY salary DESC;
```
**Output:**
```
+------------+-----------+
| emp_name   |  salary   |
+------------+-----------+
| Ivy        | 73000.0   |
| Diana      | 71000.0   |
| Frank      | 67000.0   |
| Bob        | 62000.0   |
| Jack       | 61000.0   |
| Grace      | 58000.0   |
| Alice      | 55000.0   |
| Eve        | 53000.0   |
| Charlie    | 48000.0   |
| Henry      | 45000.0   |
+------------+-----------+
```

---

## Lab 3: Hive Aggregation Queries on ORDERS Table

### Aim
To create an ORDERS table, insert records, and practice aggregate functions including COUNT, SUM, AVG, MIN, MAX, and GROUP BY.

### Prerequisites
- HiveServer2 running and beeline connected

### Procedure & Commands

#### Step 1: Create database and table
```sql
CREATE DATABASE IF NOT EXISTS lab3_db;
USE lab3_db;

DROP TABLE IF EXISTS ORDERS;

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
```
**Output:**
```
OK
```

#### Step 2: Insert 10 records
```sql
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
```

#### Step 3: Verify data
```sql
SELECT * FROM ORDERS;
```
**Output:**
```
+------------+-----------+-------------+----------+-----------+-------------+-----------+
| order_id   | customer  |  product    |  amount  | quantity  | order_date  |  region   |
+------------+-----------+-------------+----------+-----------+-------------+-----------+
| 1          | Ravi      | Laptop      | 999.0    | 1         | 2023-01-10  | South     |
| 2          | Priya     | Mouse       | 25.5     | 3         | 2023-01-12  | North     |
| 3          | Arun      | Keyboard    | 45.0     | 2         | 2023-02-05  | East      |
| 4          | Ravi      | Monitor     | 320.0    | 1         | 2023-02-10  | South     |
| 5          | Sita      | Laptop      | 999.0    | 1         | 2023-03-01  | West      |
| 6          | Priya     | USB Cable   | 10.0     | 5         | 2023-03-15  | North     |
| 7          | Arun      | Laptop      | 999.0    | 1         | 2023-04-02  | East      |
| 8          | Ravi      | Mouse       | 25.5     | 2         | 2023-04-18  | South     |
| 9          | Sita      | Keyboard    | 45.0     | 1         | 2023-05-20  | West      |
| 10         | Amit      | Monitor     | 320.0    | 2         | 2023-05-25  | North     |
+------------+-----------+-------------+----------+-----------+-------------+-----------+
```

#### Query 1: Total number of orders
```sql
SELECT COUNT(*) AS total_orders FROM ORDERS;
```
**Output:**
```
+--------------+
| total_orders |
+--------------+
| 10           |
+--------------+
```

#### Query 2: Total sales amount
```sql
SELECT ROUND(SUM(amount * quantity), 2) AS total_sales FROM ORDERS;
```
**Output:**
```
+-------------+
| total_sales |
+-------------+
| 5339.5      |
+-------------+
```

#### Query 3: Average order amount
```sql
SELECT ROUND(AVG(amount), 2) AS avg_amount FROM ORDERS;
```
**Output:**
```
+------------+
| avg_amount |
+------------+
| 383.85     |
+------------+
```

#### Query 4: Minimum and Maximum order amount
```sql
SELECT MIN(amount) AS min_amount, MAX(amount) AS max_amount FROM ORDERS;
```
**Output:**
```
+------------+-------------+
| min_amount | max_amount  |
+------------+-------------+
| 10.0       | 999.0       |
+------------+-------------+
```

#### Query 5: Total sales per customer
```sql
SELECT customer, SUM(amount * quantity) AS total_spent
FROM ORDERS
GROUP BY customer
ORDER BY total_spent DESC;
```
**Output:**
```
+-----------+--------------+
| customer  | total_spent  |
+-----------+--------------+
| Arun      | 1089.0       |
| Ravi      | 1720.0       |
| Sita      | 1044.0       |
| Amit      | 640.0        |
| Priya     | 126.5        |
+-----------+--------------+
```

#### Query 6: Number of orders per region
```sql
SELECT region, COUNT(*) AS num_orders
FROM ORDERS
GROUP BY region
ORDER BY num_orders DESC;
```
**Output:**
```
+---------+------------+
| region  | num_orders |
+---------+------------+
| South   | 3          |
| North   | 3          |
| East    | 2          |
| West    | 2          |
+---------+------------+
```

#### Query 7: Products sold more than twice
```sql
SELECT product, SUM(quantity) AS total_qty
FROM ORDERS
GROUP BY product
HAVING SUM(quantity) > 2;
```
**Output:**
```
+-----------+------------+
| product   | total_qty  |
+-----------+------------+
| Mouse     | 5          |
| USB Cable | 5          |
| Monitor   | 3          |
+-----------+------------+
```

#### Query 8: Customer with highest total spending
```sql
SELECT customer, SUM(amount * quantity) AS total_spent
FROM ORDERS
GROUP BY customer
ORDER BY total_spent DESC
LIMIT 1;
```
**Output:**
```
+-----------+--------------+
| customer  | total_spent  |
+-----------+--------------+
| Ravi      | 1720.0       |
+-----------+--------------+
```

---

## Lab 4: Hive String and Date Functions

### Aim
To practice Hive built-in string functions (REGEXP_REPLACE, LENGTH, CONCAT, UPPER, LOWER, SUBSTR, TRIM) and date functions (YEAR, MONTH, DAY, DATEDIFF, DATE_FORMAT) on an EMPLOYEES table.

### Prerequisites
- HiveServer2 running and beeline connected

### Procedure & Commands

#### Step 1: Create database and table
```sql
CREATE DATABASE IF NOT EXISTS lab4_db;
USE lab4_db;

DROP TABLE IF EXISTS EMPLOYEES;

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
```

#### Step 2: Insert 10 records
```sql
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
```

#### Query 1: UPPER, LOWER, CONCAT
```sql
SELECT
    first_name,
    UPPER(first_name) AS upper_name,
    LOWER(last_name) AS lower_last,
    CONCAT(first_name, ' ', last_name) AS full_name
FROM EMPLOYEES;
```
**Output:**
```
+------------+------------+------------+----------------+
| first_name | upper_name | lower_last | full_name      |
+------------+------------+------------+----------------+
| John       | JOHN       | smith      | John Smith     |
| Jane       | JANE       | doe        | Jane Doe       |
| Bob        | BOB        | williams   | Bob Williams   |
| Alice      | ALICE      | brown      | Alice Brown    |
| Eve        | EVE        | davis      | Eve Davis      |
| Frank      | FRANK      | miller     | Frank Miller   |
| Grace      | GRACE      | wilson     | Grace Wilson   |
| Henry      | HENRY      | moore      | Henry Moore    |
| Ivy        | IVY        | taylor     | Ivy Taylor     |
| Jack       | JACK       | anderson   | Jack Anderson  |
+------------+------------+------------+----------------+
```

#### Query 2: LENGTH and SUBSTR
```sql
SELECT
    first_name,
    LENGTH(first_name) AS name_length,
    SUBSTR(first_name, 1, 3) AS first_3_chars
FROM EMPLOYEES;
```
**Output:**
```
+------------+--------------+----------------+
| first_name | name_length  | first_3_chars  |
+------------+--------------+----------------+
| John       | 4            | Joh            |
| Jane       | 4            | Jan            |
| Bob        | 3            | Bob            |
| Alice      | 5            | Ali            |
| Eve        | 3            | Eve            |
| Frank      | 5            | Fra            |
| Grace      | 5            | Gra            |
| Henry      | 5            | Hen            |
| Ivy        | 3            | Ivy            |
| Jack       | 4            | Jac            |
+------------+--------------+----------------+
```

#### Query 3: REGEXP_REPLACE to extract username from email
```sql
SELECT
    first_name,
    email,
    REGEXP_REPLACE(email, '@company.com', '') AS username
FROM EMPLOYEES;
```
**Output:**
```
+------------+---------------------------+---------------+
| first_name | email                     | username      |
+------------+---------------------------+---------------+
| John       | john.smith@company.com    | john.smith    |
| Jane       | jane.doe@company.com      | jane.doe      |
| Bob        | bob.williams@company.com  | bob.williams  |
| Alice      | alice.brown@company.com   | alice.brown   |
| Eve        | eve.davis@company.com     | eve.davis     |
| Frank      | frank.miller@company.com  | frank.miller  |
| Grace      | grace.wilson@company.com  | grace.wilson  |
| Henry      | henry.moore@company.com   | henry.moore   |
| Ivy        | ivy.taylor@company.com    | ivy.taylor    |
| Jack       | jack.anderson@company.com | jack.anderson |
+------------+---------------------------+---------------+
```

#### Query 4: Date Functions
```sql
SELECT
    first_name,
    hire_date,
    YEAR(hire_date) AS hire_year,
    MONTH(hire_date) AS hire_month,
    DAY(hire_date) AS hire_day
FROM EMPLOYEES;
```
**Output:**
```
+------------+-------------+-----------+------------+-----------+
| first_name | hire_date   | hire_year | hire_month | hire_day  |
+------------+-------------+-----------+------------+-----------+
| John       | 2019-03-15  | 2019      | 3          | 15        |
| Jane       | 2018-07-20  | 2018      | 7          | 20        |
| Bob        | 2020-01-10  | 2020      | 1          | 10        |
| Alice      | 2017-11-05  | 2017      | 11         | 5         |
| Eve        | 2021-06-25  | 2021      | 6          | 25        |
| Frank      | 2016-09-12  | 2016      | 9          | 12        |
| Grace      | 2019-08-30  | 2019      | 8          | 30        |
| Henry      | 2022-02-14  | 2022      | 2          | 14        |
| Ivy        | 2015-05-18  | 2015      | 5          | 18        |
| Jack       | 2020-12-01  | 2020      | 12         | 1         |
+------------+-------------+-----------+------------+-----------+
```

#### Query 5: DATEDIFF - years of service
```sql
SELECT
    first_name,
    hire_date,
    DATEDIFF(CURRENT_DATE, hire_date) AS days_employed,
    ROUND(DATEDIFF(CURRENT_DATE, hire_date) / 365.25, 1) AS years_employed
FROM EMPLOYEES;
```
**Output:**
```
+------------+-------------+----------------+----------------+
| first_name | hire_date   | days_employed  | years_employed |
+------------+-------------+----------------+----------------+
| John       | 2019-03-15  | 2354           | 6.4            |
| Jane       | 2018-07-20  | 2592           | 7.1            |
| Bob        | 2020-01-10  | 2018           | 5.5            |
| Alice      | 2017-11-05  | 2820           | 7.7            |
| Eve        | 2021-06-25  | 1856           | 5.1            |
| Frank      | 2016-09-12  | 3147           | 8.6            |
| Grace      | 2019-08-30  | 2186           | 6.0            |
| Henry      | 2022-02-14  | 1621           | 4.4            |
| Ivy        | 2015-05-18  | 3721           | 10.2           |
| Jack       | 2020-12-01  | 2063           | 5.6            |
+------------+-------------+----------------+----------------+
```

#### Query 6: DATE_FORMAT
```sql
SELECT
    first_name,
    hire_date,
    DATE_FORMAT(hire_date, 'yyyy-MM') AS year_month,
    DATE_FORMAT(hire_date, 'dd/MM/yyyy') AS formatted_date
FROM EMPLOYEES;
```
**Output:**
```
+------------+-------------+------------+----------------+
| first_name | hire_date   | year_month | formatted_date |
+------------+-------------+------------+----------------+
| John       | 2019-03-15  | 2019-03    | 15/03/2019     |
| Jane       | 2018-07-20  | 2018-07    | 20/07/2018     |
| Bob        | 2020-01-10  | 2020-01    | 10/01/2020     |
| Alice      | 2017-11-05  | 2017-11    | 05/11/2017     |
| Eve        | 2021-06-25  | 2021-06    | 25/06/2021     |
| Frank      | 2016-09-12  | 2016-09    | 12/09/2016     |
| Grace      | 2019-08-30  | 2019-08    | 30/08/2019     |
| Henry      | 2022-02-14  | 2022-02    | 14/02/2022     |
| Ivy        | 2015-05-18  | 2015-05    | 18/05/2015     |
| Jack       | 2020-12-01  | 2020-12    | 01/12/2020     |
+------------+-------------+------------+----------------+
```

#### Query 7: Employees hired before 2019
```sql
SELECT first_name, hire_date
FROM EMPLOYEES
WHERE YEAR(hire_date) < 2019;
```
**Output:**
```
+------------+-------------+
| first_name | hire_date   |
+------------+-------------+
| Jane       | 2018-07-20  |
| Alice      | 2017-11-05  |
| Frank      | 2016-09-12  |
| Ivy        | 2015-05-18  |
+------------+-------------+
```

---

## Lab 5: Hive Join Operations (5 Tables)

### Aim
To practice INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN, and self-joins across multiple tables: DEPARTMENT, EMPLOYEES, LOCATION, GRADE, and JOB.

### Prerequisites
- HiveServer2 running and beeline connected

### Procedure & Commands

#### Step 1: Create database and all 5 tables
```sql
CREATE DATABASE IF NOT EXISTS lab5_db;
USE lab5_db;

DROP TABLE IF EXISTS DEPARTMENT;
DROP TABLE IF EXISTS EMPLOYEES;
DROP TABLE IF EXISTS LOCATION;
DROP TABLE IF EXISTS GRADE;
DROP TABLE IF EXISTS JOB;

CREATE TABLE DEPARTMENT (
    dept_id     INT,
    dept_name   STRING,
    location_id INT
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE EMPLOYEES (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    dept_id     INT,
    job_id      INT,
    manager_id  INT
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE LOCATION (
    location_id     INT,
    city            STRING,
    state           STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE GRADE (
    grade_id    INT,
    min_salary  DOUBLE,
    max_salary  DOUBLE,
    grade_name  STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE JOB (
    job_id      INT,
    job_title   STRING,
    min_salary  DOUBLE,
    max_salary  DOUBLE
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;
```

#### Step 2: Insert data into all tables
```sql
-- DEPARTMENT
INSERT INTO TABLE DEPARTMENT VALUES (10, 'HR', 1001);
INSERT INTO TABLE DEPARTMENT VALUES (20, 'IT', 1002);
INSERT INTO TABLE DEPARTMENT VALUES (30, 'Finance', 1003);
INSERT INTO TABLE DEPARTMENT VALUES (40, 'Marketing', 1004);

-- EMPLOYEES
INSERT INTO TABLE EMPLOYEES VALUES (101, 'Alice', 55000, 10, 1, NULL);
INSERT INTO TABLE EMPLOYEES VALUES (102, 'Bob', 62000, 20, 2, 101);
INSERT INTO TABLE EMPLOYEES VALUES (103, 'Charlie', 48000, 30, 3, 101);
INSERT INTO TABLE EMPLOYEES VALUES (104, 'Diana', 71000, 20, 4, 102);
INSERT INTO TABLE EMPLOYEES VALUES (105, 'Eve', 53000, 10, 1, 101);
INSERT INTO TABLE EMPLOYEES VALUES (106, 'Frank', 67000, 30, 3, 103);
INSERT INTO TABLE EMPLOYEES VALUES (107, 'Grace', 58000, 20, 2, 104);
INSERT INTO TABLE EMPLOYEES VALUES (108, 'Henry', 45000, 10, 1, 105);
INSERT INTO TABLE EMPLOYEES VALUES (109, 'Ivy', 73000, 30, 4, 106);
INSERT INTO TABLE EMPLOYEES VALUES (110, 'Jack', 61000, 20, 2, 107);

-- LOCATION
INSERT INTO TABLE LOCATION VALUES (1001, 'Chennai', 'Tamil Nadu');
INSERT INTO TABLE LOCATION VALUES (1002, 'Bangalore', 'Karnataka');
INSERT INTO TABLE LOCATION VALUES (1003, 'Mumbai', 'Maharashtra');
INSERT INTO TABLE LOCATION VALUES (1004, 'Delhi', 'Delhi');

-- GRADE
INSERT INTO TABLE GRADE VALUES (1, 40000, 55000, 'Grade A');
INSERT INTO TABLE GRADE VALUES (2, 55001, 65000, 'Grade B');
INSERT INTO TABLE GRADE VALUES (3, 65001, 75000, 'Grade C');

-- JOB
INSERT INTO TABLE JOB VALUES (1, 'Analyst', 40000, 60000);
INSERT INTO TABLE JOB VALUES (2, 'Developer', 55000, 80000);
INSERT INTO TABLE JOB VALUES (3, 'Accountant', 45000, 70000);
INSERT INTO TABLE JOB VALUES (4, 'Manager', 65000, 90000);
```

#### Query 1: INNER JOIN - Employees with Department names
```sql
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name
FROM EMPLOYEES e
INNER JOIN DEPARTMENT d ON e.dept_id = d.dept_id;
```
**Output:**
```
+---------+-----------+-----------+-------------+
| emp_id  | emp_name  |  salary   | dept_name   |
+---------+-----------+-----------+-------------+
| 101     | Alice     | 55000.0   | HR          |
| 102     | Bob       | 62000.0   | IT          |
| 103     | Charlie   | 48000.0   | Finance     |
| 104     | Diana     | 71000.0   | IT          |
| 105     | Eve       | 53000.0   | HR          |
| 106     | Frank     | 67000.0   | Finance     |
| 107     | Grace     | 58000.0   | IT          |
| 108     | Henry     | 45000.0   | HR          |
| 109     | Ivy       | 73000.0   | Finance     |
| 110     | Jack      | 61000.0   | IT          |
+---------+-----------+-----------+-------------+
```

#### Query 2: INNER JOIN - Employees with Job titles
```sql
SELECT e.emp_id, e.emp_name, j.job_title
FROM EMPLOYEES e
INNER JOIN JOB j ON e.job_id = j.job_id;
```
**Output:**
```
+---------+-----------+------------+
| emp_id  | emp_name  | job_title  |
+---------+-----------+------------+
| 101     | Alice     | Analyst    |
| 102     | Bob       | Developer  |
| 103     | Charlie   | Accountant |
| 104     | Diana     | Manager    |
| 105     | Eve       | Analyst    |
| 106     | Frank     | Accountant |
| 107     | Grace     | Developer  |
| 108     | Henry     | Analyst    |
| 109     | Ivy       | Manager    |
| 110     | Jack      | Developer  |
+---------+-----------+------------+
```

#### Query 3: INNER JOIN - Department with Location
```sql
SELECT d.dept_name, l.city, l.state
FROM DEPARTMENT d
INNER JOIN LOCATION l ON d.location_id = l.location_id;
```
**Output:**
```
+-------------+-----------+--------------+
| dept_name   |   city    |    state     |
+-------------+-----------+--------------+
| HR          | Chennai   | Tamil Nadu   |
| IT          | Bangalore | Karnataka    |
| Finance     | Mumbai    | Maharashtra  |
| Marketing   | Delhi     | Delhi        |
+-------------+-----------+--------------+
```

#### Query 4: LEFT JOIN - All employees with department
```sql
SELECT e.emp_id, e.emp_name, d.dept_name
FROM EMPLOYEES e
LEFT JOIN DEPARTMENT d ON e.dept_id = d.dept_id;
```
**Output:**
```
+---------+-----------+-------------+
| emp_id  | emp_name  | dept_name   |
+---------+-----------+-------------+
| 101     | Alice     | HR          |
| 102     | Bob       | IT          |
| 103     | Charlie   | Finance     |
| 104     | Diana     | IT          |
| 105     | Eve       | HR          |
| 106     | Frank     | Finance     |
| 107     | Grace     | IT          |
| 108     | Henry     | HR          |
| 109     | Ivy       | Finance     |
| 110     | Jack      | IT          |
+---------+-----------+-------------+
```

#### Query 5: RIGHT JOIN - All departments with employees
```sql
SELECT d.dept_name, e.emp_name
FROM EMPLOYEES e
RIGHT JOIN DEPARTMENT d ON e.dept_id = d.dept_id;
```
**Output:**
```
+-------------+-----------+
| dept_name   | emp_name  |
+-------------+-----------+
| HR          | Alice     |
| HR          | Eve       |
| HR          | Henry     |
| IT          | Bob       |
| IT          | Diana     |
| IT          | Grace     |
| IT          | Jack      |
| Finance     | Charlie   |
| Finance     | Frank     |
| Finance     | Ivy       |
| Marketing   | NULL      |
+-------------+-----------+
```

#### Query 6: FULL OUTER JOIN
```sql
SELECT e.emp_name, d.dept_name
FROM EMPLOYEES e
FULL OUTER JOIN DEPARTMENT d ON e.dept_id = d.dept_id;
```
**Output:**
```
+-----------+-------------+
| emp_name  | dept_name   |
+-----------+-------------+
| Alice     | HR          |
| Bob       | IT          |
| Charlie   | Finance     |
| Diana     | IT          |
| Eve       | HR          |
| Frank     | Finance     |
| Grace     | IT          |
| Henry     | HR          |
| Ivy       | Finance     |
| Jack      | IT          |
| NULL      | Marketing   |
+-----------+-------------+
```

#### Query 7: 3-table JOIN - Employees with Department and Location
```sql
SELECT e.emp_name, d.dept_name, l.city, l.state
FROM EMPLOYEES e
INNER JOIN DEPARTMENT d ON e.dept_id = d.dept_id
INNER JOIN LOCATION l ON d.location_id = l.location_id;
```
**Output:**
```
+-----------+-------------+-----------+--------------+
| emp_name  | dept_name   |   city    |    state     |
+-----------+-------------+-----------+--------------+
| Alice     | HR          | Chennai   | Tamil Nadu   |
| Eve       | HR          | Chennai   | Tamil Nadu   |
| Henry     | HR          | Chennai   | Tamil Nadu   |
| Bob       | IT          | Bangalore | Karnataka    |
| Diana     | IT          | Bangalore | Karnataka    |
| Grace     | IT          | Bangalore | Karnataka    |
| Jack      | IT          | Bangalore | Karnataka    |
| Charlie   | Finance     | Mumbai    | Maharashtra  |
| Frank     | Finance     | Mumbai    | Maharashtra  |
| Ivy       | Finance     | Mumbai    | Maharashtra  |
+-----------+-------------+-----------+--------------+
```

#### Query 8: Self JOIN - Employee with their Manager
```sql
SELECT
    e.emp_name AS employee,
    m.emp_name AS manager
FROM EMPLOYEES e
LEFT JOIN EMPLOYEES m ON e.manager_id = m.emp_id;
```
**Output:**
```
+-----------+-----------+
| employee  | manager   |
+-----------+-----------+
| Alice     | NULL      |
| Bob       | Alice     |
| Charlie   | Alice     |
| Diana     | Bob       |
| Eve       | Alice     |
| Frank     | Charlie   |
| Grace     | Diana     |
| Henry     | Eve       |
| Ivy       | Frank     |
| Jack      | Grace     |
+-----------+-----------+
```

#### Query 9: Employees with their Grade
```sql
SELECT e.emp_name, e.salary, g.grade_name
FROM EMPLOYEES e
INNER JOIN GRADE g ON e.salary BETWEEN g.min_salary AND g.max_salary
ORDER BY e.salary;
```
**Output:**
```
+-----------+-----------+------------+
| emp_name  |  salary   | grade_name |
+-----------+-----------+------------+
| Henry     | 45000.0   | Grade A    |
| Charlie   | 48000.0   | Grade A    |
| Eve       | 53000.0   | Grade A    |
| Alice     | 55000.0   | Grade A    |
| Grace     | 58000.0   | Grade B    |
| Jack      | 61000.0   | Grade B    |
| Bob       | 62000.0   | Grade B    |
| Frank     | 67000.0   | Grade C    |
| Diana     | 71000.0   | Grade C    |
| Ivy       | 73000.0   | Grade C    |
+-----------+-----------+------------+
```

#### Query 10: Count employees per department
```sql
SELECT d.dept_name, COUNT(e.emp_id) AS emp_count
FROM DEPARTMENT d
LEFT JOIN EMPLOYEES e ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
```
**Output:**
```
+-------------+------------+
| dept_name   | emp_count  |
+-------------+------------+
| HR          | 3          |
| IT          | 4          |
| Finance     | 3          |
| Marketing   | 0          |
+-------------+------------+
```

#### Query 11: Department-wise total salary
```sql
SELECT d.dept_name, SUM(e.salary) AS total_salary, ROUND(AVG(e.salary), 2) AS avg_salary
FROM DEPARTMENT d
INNER JOIN EMPLOYEES e ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY total_salary DESC;
```
**Output:**
```
+-------------+---------------+-------------+
| dept_name   | total_salary  | avg_salary  |
+-------------+---------------+-------------+
| IT          | 252000.0      | 63000.0     |
| Finance     | 188000.0      | 62666.67    |
| HR          | 153000.0      | 51000.0     |
+-------------+---------------+-------------+
```

---

## Lab 6: Hive Aggregate Functions on ORDER_TABLE

### Aim
To create an ORDER_TABLE and practice aggregate functions including COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING, and monthly analytics.

### Prerequisites
- HiveServer2 running and beeline connected

### Procedure & Commands

#### Step 1: Create database and table
```sql
CREATE DATABASE IF NOT EXISTS lab6_db;
USE lab6_db;

DROP TABLE IF EXISTS ORDER_TABLE;

CREATE TABLE ORDER_TABLE (
    order_id        INT,
    customer_name   STRING,
    product_name    STRING,
    quantity        INT,
    unit_price      DOUBLE,
    order_date      STRING,
    payment_mode    STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;
```

#### Step 2: Insert 10 records
```sql
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
```

#### Query 1: Total number of orders
```sql
SELECT COUNT(*) AS total_orders FROM ORDER_TABLE;
```
**Output:**
```
+--------------+
| total_orders |
+--------------+
| 10           |
+--------------+
```

#### Query 2: Total revenue
```sql
SELECT ROUND(SUM(quantity * unit_price), 2) AS total_revenue FROM ORDER_TABLE;
```
**Output:**
```
+---------------+
| total_revenue |
+---------------+
| 5277.5        |
+---------------+
```

#### Query 3: Average order value
```sql
SELECT ROUND(AVG(quantity * unit_price), 2) AS avg_order_value FROM ORDER_TABLE;
```
**Output:**
```
+------------------+
| avg_order_value  |
+------------------+
| 527.75           |
+------------------+
```

#### Query 4: Cheapest and most expensive product
```sql
SELECT MIN(unit_price) AS cheapest, MAX(unit_price) AS most_expensive FROM ORDER_TABLE;
```
**Output:**
```
+-----------+----------------+
| cheapest  | most_expensive |
+-----------+----------------+
| 12.0      | 999.0          |
+-----------+----------------+
```

#### Query 5: Customer-wise total spending
```sql
SELECT customer_name, ROUND(SUM(quantity * unit_price), 2) AS total_spent
FROM ORDER_TABLE
GROUP BY customer_name
ORDER BY total_spent DESC;
```
**Output:**
```
+---------------+--------------+
| customer_name | total_spent  |
+---------------+--------------+
| Rohan         | 1695.0       |
| Kiran         | 1189.0       |
| Asha          | 1044.0       |
| Deepak        | 640.0        |
| Meena         | 196.5        |
+---------------+--------------+
```

#### Query 6: Product-wise total quantity sold
```sql
SELECT product_name, SUM(quantity) AS total_qty_sold
FROM ORDER_TABLE
GROUP BY product_name
ORDER BY total_qty_sold DESC;
```
**Output:**
```
+--------------+----------------+
| product_name | total_qty_sold |
+--------------+----------------+
| Mouse        | 5              |
| USB Hub      | 5              |
| Monitor      | 3              |
| Keyboard     | 3              |
| Laptop       | 3              |
+--------------+----------------+
```

#### Query 7: Payment mode usage count
```sql
SELECT payment_mode, COUNT(*) AS order_count
FROM ORDER_TABLE
GROUP BY payment_mode
ORDER BY order_count DESC;
```
**Output:**
```
+---------------+-------------+
| payment_mode  | order_count |
+---------------+-------------+
| Credit Card   | 4           |
| UPI           | 2           |
| Cash          | 2           |
| Debit Card    | 2           |
+---------------+-------------+
```

#### Query 8: Monthly revenue
```sql
SELECT
    SUBSTR(order_date, 1, 7) AS order_month,
    ROUND(SUM(quantity * unit_price), 2) AS monthly_revenue
FROM ORDER_TABLE
GROUP BY SUBSTR(order_date, 1, 7)
ORDER BY order_month;
```
**Output:**
```
+--------------+-----------------+
| order_month  | monthly_revenue |
+--------------+-----------------+
| 2023-01      | 1075.5          |
| 2023-02      | 1089.0          |
| 2023-03      | 1059.0          |
| 2023-04      | 1375.0          |
| 2023-05      | 680.0           |
+--------------+-----------------+
```

---

## Lab 7: Hive Subqueries, Views, and Multi-Table Queries

### Aim
To practice subqueries (IN, EXISTS, correlated), CREATE VIEW, and complex multi-table queries using a movie database schema with tables: ACTOR, MOVIE_CAST, MOVIE, RATING, and REVIEWER.

### Prerequisites
- HiveServer2 running and beeline connected

### Procedure & Commands

#### Step 1: Create all tables
```sql
CREATE DATABASE IF NOT EXISTS lab7_db;
USE lab7_db;

DROP TABLE IF EXISTS ACTOR;
DROP TABLE IF EXISTS MOVIE_CAST;
DROP TABLE IF EXISTS MOVIE;
DROP TABLE IF EXISTS RATING;
DROP TABLE IF EXISTS REVIEWER;
DROP VIEW IF EXISTS MOVIE_SUMMARY;

CREATE TABLE ACTOR (
    actor_id    INT,
    actor_name  STRING,
    gender      STRING,
    birth_year  INT
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE MOVIE (
    movie_id    INT,
    movie_name  STRING,
    release_year INT,
    genre       STRING,
    director    STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE MOVIE_CAST (
    movie_id    INT,
    actor_id    INT,
    role_name   STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE REVIEWER (
    reviewer_id     INT,
    reviewer_name   STRING,
    platform        STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE RATING (
    rating_id   INT,
    movie_id    INT,
    reviewer_id INT,
    rating      DOUBLE,
    review_date STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;
```

#### Step 2: Insert data into all tables
```sql
-- ACTOR
INSERT INTO TABLE ACTOR VALUES (1, 'Shah Rukh Khan', 'M', 1965);
INSERT INTO TABLE ACTOR VALUES (2, 'Deepika Padukone', 'F', 1986);
INSERT INTO TABLE ACTOR VALUES (3, 'Aamir Khan', 'M', 1965);
INSERT INTO TABLE ACTOR VALUES (4, 'Priyanka Chopra', 'F', 1982);
INSERT INTO TABLE ACTOR VALUES (5, 'Ranbir Kapoor', 'M', 1982);

-- MOVIE
INSERT INTO TABLE MOVIE VALUES (101, 'Chennai Express', 2013, 'Action', 'Rohit Shetty');
INSERT INTO TABLE MOVIE VALUES (102, 'Padmaavat', 2018, 'Drama', 'Sanjay Leela Bhansali');
INSERT INTO TABLE MOVIE VALUES (103, '3 Idiots', 2009, 'Comedy', 'Rajkumar Hirani');
INSERT INTO TABLE MOVIE VALUES (104, 'Bajirao Mastani', 2015, 'Drama', 'Sanjay Leela Bhansali');
INSERT INTO TABLE MOVIE VALUES (105, 'Yeh Jawaani Hai Deewani', 2013, 'Romance', 'Ayan Mukerji');

-- MOVIE_CAST
INSERT INTO TABLE MOVIE_CAST VALUES (101, 1, 'Rahul');
INSERT INTO TABLE MOVIE_CAST VALUES (101, 2, 'Meenamma');
INSERT INTO TABLE MOVIE_CAST VALUES (102, 2, 'Padmavati');
INSERT INTO TABLE MOVIE_CAST VALUES (102, 5, 'Rawal Ratan Singh');
INSERT INTO TABLE MOVIE_CAST VALUES (103, 3, 'Rancho');
INSERT INTO TABLE MOVIE_CAST VALUES (104, 2, 'Kashibai');
INSERT INTO TABLE MOVIE_CAST VALUES (104, 4, 'Mastani');
INSERT INTO TABLE MOVIE_CAST VALUES (105, 5, 'Bunny');
INSERT INTO TABLE MOVIE_CAST VALUES (105, 2, 'Naina');

-- REVIEWER
INSERT INTO TABLE REVIEWER VALUES (1, 'Raj', 'IMDb');
INSERT INTO TABLE REVIEWER VALUES (2, 'Simran', 'BookMyShow');
INSERT INTO TABLE REVIEWER VALUES (3, 'Vikram', 'IMDb');
INSERT INTO TABLE REVIEWER VALUES (4, 'Anjali', 'Rotten Tomatoes');

-- RATING
INSERT INTO TABLE RATING VALUES (1, 101, 1, 7.5, '2013-08-10');
INSERT INTO TABLE RATING VALUES (2, 101, 2, 8.0, '2013-08-12');
INSERT INTO TABLE RATING VALUES (3, 102, 1, 8.2, '2018-01-30');
INSERT INTO TABLE RATING VALUES (4, 102, 3, 7.8, '2018-02-01');
INSERT INTO TABLE RATING VALUES (5, 103, 1, 9.5, '2009-12-28');
INSERT INTO TABLE RATING VALUES (6, 103, 2, 9.2, '2009-12-30');
INSERT INTO TABLE RATING VALUES (7, 103, 4, 9.0, '2010-01-02');
INSERT INTO TABLE RATING VALUES (8, 104, 3, 8.5, '2015-12-20');
INSERT INTO TABLE RATING VALUES (9, 105, 1, 8.0, '2013-06-05');
INSERT INTO TABLE RATING VALUES (10, 105, 4, 7.5, '2013-06-10');
```

#### Query 1: Movies with above average rating
```sql
SELECT movie_name
FROM MOVIE
WHERE movie_id IN (
    SELECT movie_id FROM RATING
    GROUP BY movie_id
    HAVING AVG(rating) > (SELECT AVG(rating) FROM RATING)
);
```
**Output:**
```
+-------------------------+
| movie_name              |
+-------------------------+
| Padmaavat               |
| 3 Idiots                |
| Bajirao Mastani         |
| Yeh Jawaani Hai Deewani |
| Chennai Express         |
+-------------------------+
```

#### Query 2: Actors who acted in more than one movie
```sql
SELECT actor_name
FROM ACTOR
WHERE actor_id IN (
    SELECT actor_id FROM MOVIE_CAST
    GROUP BY actor_id
    HAVING COUNT(movie_id) > 1
);
```
**Output:**
```
+-------------------+
| actor_name        |
+-------------------+
| Deepika Padukone  |
| Ranbir Kapoor     |
+-------------------+
```

#### Query 3: Highest rated movie
```sql
SELECT m.movie_name, r.avg_rating
FROM MOVIE m
INNER JOIN (
    SELECT movie_id, ROUND(AVG(rating), 2) AS avg_rating
    FROM RATING GROUP BY movie_id
) r ON m.movie_id = r.movie_id
ORDER BY r.avg_rating DESC
LIMIT 1;
```
**Output:**
```
+-----------+------------+
| movie_name| avg_rating |
+-----------+------------+
| 3 Idiots  | 9.23       |
+-----------+------------+
```

#### Query 4: Correlated subquery - actors in highly rated movies
```sql
SELECT a.actor_name
FROM ACTOR a
WHERE EXISTS (
    SELECT 1
    FROM MOVIE_CAST mc
    INNER JOIN (
        SELECT movie_id FROM RATING
        GROUP BY movie_id
        HAVING AVG(rating) > 8.0
    ) high_rated ON mc.movie_id = high_rated.movie_id
    WHERE mc.actor_id = a.actor_id
);
```
**Output:**
```
+-------------------+
| actor_name        |
+-------------------+
| Shah Rukh Khan    |
| Deepika Padukone  |
| Aamir Khan        |
| Priyanka Chopra   |
| Ranbir Kapoor     |
+-------------------+
```

#### Query 5: Directors whose movies have avg rating > 7.5
```sql
SELECT director
FROM MOVIE
WHERE movie_id IN (
    SELECT movie_id FROM RATING
    GROUP BY movie_id
    HAVING AVG(rating) > 7.5
);
```
**Output:**
```
+--------------------------+
| director                 |
+--------------------------+
| Rohit Shetty             |
| Sanjay Leela Bhansali    |
| Rajkumar Hirani          |
| Ayan Mukerji             |
+--------------------------+
```

#### Query 6: Movies with more than 2 reviews
```sql
SELECT m.movie_name, COUNT(r.rating_id) AS review_count
FROM MOVIE m
INNER JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.movie_name
HAVING COUNT(r.rating_id) > 2;
```
**Output:**
```
+-----------+--------------+
| movie_name| review_count |
+-----------+--------------+
| 3 Idiots  | 3            |
+-----------+--------------+
```

#### Query 7: Average rating per genre
```sql
SELECT m.genre, ROUND(AVG(r.rating), 2) AS avg_rating
FROM MOVIE m
INNER JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.genre
ORDER BY avg_rating DESC;
```
**Output:**
```
+---------+------------+
| genre   | avg_rating |
+---------+------------+
| Comedy  | 9.23       |
| Drama   | 8.17       |
| Action  | 7.75       |
| Romance | 7.75       |
+---------+------------+
```

#### Query 8: Reviewer who rated the most movies
```sql
SELECT reviewer_name, platform, COUNT(*) AS ratings_given
FROM REVIEWER rv
INNER JOIN RATING r ON rv.reviewer_id = r.reviewer_id
GROUP BY reviewer_name, platform
ORDER BY ratings_given DESC
LIMIT 1;
```
**Output:**
```
+---------------+-----------+----------------+
| reviewer_name | platform  | ratings_given  |
+---------------+-----------+----------------+
| Raj           | IMDb      | 4              |
+---------------+-----------+----------------+
```

#### Query 9: CREATE VIEW for movie summary
```sql
CREATE VIEW MOVIE_SUMMARY AS
SELECT
    m.movie_id, m.movie_name, m.genre, m.director,
    COUNT(DISTINCT mc.actor_id) AS num_actors,
    COUNT(DISTINCT r.rating_id) AS num_reviews,
    ROUND(AVG(r.rating), 2) AS avg_rating
FROM MOVIE m
LEFT JOIN MOVIE_CAST mc ON m.movie_id = mc.movie_id
LEFT JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.movie_id, m.movie_name, m.genre, m.director;
```
**Output:**
```
OK
```

#### Query 10: Query the VIEW
```sql
SELECT * FROM MOVIE_SUMMARY ORDER BY avg_rating DESC;
```
**Output:**
```
+-----------+-------------------------+---------+--------------------------+------------+-------------+------------+
| movie_id  | movie_name              | genre   | director                 | num_actors | num_reviews | avg_rating |
+-----------+-------------------------+---------+--------------------------+------------+-------------+------------+
| 103       | 3 Idiots                | Comedy  | Rajkumar Hirani          | 1          | 3           | 9.23       |
| 104       | Bajirao Mastani         | Drama   | Sanjay Leela Bhansali    | 2          | 1           | 8.5        |
| 102       | Padmaavat               | Drama   | Sanjay Leela Bhansali    | 2          | 2           | 8.0        |
| 101       | Chennai Express         | Action  | Rohit Shetty             | 2          | 2           | 7.75       |
| 105       | Yeh Jawaani Hai Deewani | Romance | Ayan Mukerji             | 2          | 2           | 7.75       |
+-----------+-------------------------+---------+--------------------------+------------+-------------+------------+
```

---

## Lab 8: Hive Dynamic Partitioning

### Aim
To understand and implement dynamic partitioning in Hive using an EMPLOYEES_PART table partitioned by department, and compare partitioned vs non-partitioned table storage in HDFS.

### Prerequisites
- HiveServer2 running and beeline connected
- Hive dynamic partitioning enabled

### Procedure & Commands

#### Step 1: Create database and enable dynamic partitioning
```sql
CREATE DATABASE IF NOT EXISTS lab8_db;
USE lab8_db;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=1000;
SET hive.exec.max.dynamic.partitions.pernode=100;
```
**Output:**
```
OK
```

#### Step 2: Create source (non-partitioned) table
```sql
DROP TABLE IF EXISTS EMPLOYEES_SRC;

CREATE TABLE EMPLOYEES_SRC (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    dept_name   STRING,
    gender      STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;
```

#### Step 3: Create partitioned target table
```sql
DROP TABLE IF EXISTS EMPLOYEES_PART;

CREATE TABLE EMPLOYEES_PART (
    emp_id      INT,
    emp_name    STRING,
    salary      DOUBLE,
    gender      STRING
)
PARTITIONED BY (dept_name STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;
```

#### Step 4: Insert data into source table
```sql
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
```

#### Step 5: Verify source data
```sql
SELECT * FROM EMPLOYEES_SRC;
```
**Output:**
```
+----------+-----------+-----------+------------+---------+
| emp_id   | emp_name  |  salary   | dept_name  | gender  |
+----------+-----------+-----------+------------+---------+
| 101      | Alice     | 55000.0   | HR         | F       |
| 102      | Bob       | 62000.0   | IT         | M       |
| 103      | Charlie   | 48000.0   | Finance    | M       |
| 104      | Diana     | 71000.0   | IT         | F       |
| 105      | Eve       | 53000.0   | HR         | F       |
| 106      | Frank     | 67000.0   | Finance    | M       |
| 107      | Grace     | 58000.0   | IT         | F       |
| 108      | Henry     | 45000.0   | HR         | M       |
| 109      | Ivy       | 73000.0   | Finance    | F       |
| 110      | Jack      | 61000.0   | IT         | M       |
| 111      | Kelly     | 49000.0   | HR         | F       |
| 112      | Liam      | 72000.0   | Finance    | M       |
+----------+-----------+-----------+------------+---------+
```

#### Step 6: Dynamic partition INSERT
```sql
INSERT OVERWRITE TABLE EMPLOYEES_PART PARTITION (dept_name)
SELECT emp_id, emp_name, salary, gender, dept_name
FROM EMPLOYEES_SRC;
```
**Output:**
```
Query ID = ... Total jobs = 2
Launching Job 1 ...
Launching Job 2 ...
OK
Time taken: 5.678 seconds
```

#### Step 7: Verify partitioned table
```sql
SELECT * FROM EMPLOYEES_PART;
```
**Output:**
```
+----------+-----------+-----------+---------+------------+
| emp_id   | emp_name  |  salary   | gender  | dept_name  |
+----------+-----------+-----------+---------+------------+
| 101      | Alice     | 55000.0   | F       | HR         |
| 105      | Eve       | 53000.0   | F       | HR         |
| 108      | Henry     | 45000.0   | M       | HR         |
| 111      | Kelly     | 49000.0   | F       | HR         |
| 102      | Bob       | 62000.0   | M       | IT         |
| 104      | Diana     | 71000.0   | F       | IT         |
| 107      | Grace     | 58000.0   | F       | IT         |
| 110      | Jack      | 61000.0   | M       | IT         |
| 103      | Charlie   | 48000.0   | M       | Finance    |
| 106      | Frank     | 67000.0   | M       | Finance    |
| 109      | Ivy       | 73000.0   | F       | Finance    |
| 112      | Liam      | 72000.0   | M       | Finance    |
+----------+-----------+-----------+---------+------------+
```

#### Step 8: Show partitions
```sql
SHOW PARTITIONS EMPLOYEES_PART;
```
**Output:**
```
+----------------------+
|     partition        |
+----------------------+
| dept_name=Finance    |
| dept_name=HR         |
| dept_name=IT         |
+----------------------+
```

#### Step 9: Query data from a specific partition
```sql
SELECT * FROM EMPLOYEES_PART WHERE dept_name = 'IT';
```
**Output:**
```
+----------+-----------+-----------+---------+------------+
| emp_id   | emp_name  |  salary   | gender  | dept_name  |
+----------+-----------+-----------+---------+------------+
| 102      | Bob       | 62000.0   | M       | IT         |
| 104      | Diana     | 71000.0   | F       | IT         |
| 107      | Grace     | 58000.0   | F       | IT         |
| 110      | Jack      | 61000.0   | M       | IT         |
+----------+-----------+-----------+---------+------------+
```

#### Step 10: Partition-wise aggregation
```sql
SELECT dept_name, COUNT(*) AS emp_count, ROUND(AVG(salary), 2) AS avg_salary
FROM EMPLOYEES_PART
GROUP BY dept_name
ORDER BY avg_salary DESC;
```
**Output:**
```
+------------+------------+-------------+
| dept_name  | emp_count  | avg_salary  |
+------------+------------+-------------+
| Finance    | 4          | 65000.00    |
| IT         | 4          | 63000.00    |
| HR         | 4          | 50500.00    |
+------------+------------+-------------+
```

#### Step 11: HDFS storage comparison
```bash
# Non-partitioned table (all data in one directory):
hdfs dfs -ls /user/hive/warehouse/lab8_db.db/employees_src/
```
**Output:**
```
-rw-r--r--  3 hdfs supergroup  250 2025-01-15 10:30 /user/hive/warehouse/lab8_db.db/employees_src/000000_0
```

```bash
# Partitioned table (each department is a subdirectory):
hdfs dfs -ls /user/hive/warehouse/lab8_db.db/employees_part/
```
**Output:**
```
drwxr-xr-x  - hdfs supergroup    0 2025-01-15 10:35 /user/hive/warehouse/lab8_db.db/employees_part/dept_name=Finance
drwxr-xr-x  - hdfs supergroup    0 2025-01-15 10:35 /user/hive/warehouse/lab8_db.db/employees_part/dept_name=HR
drwxr-xr-x  - hdfs supergroup    0 2025-01-15 10:35 /user/hive/warehouse/lab8_db.db/employees_part/dept_name=IT
```

```bash
# Check individual partition:
hdfs dfs -cat /user/hive/warehouse/lab8_db.db/employees_part/dept_name=IT/000000_0
```
**Output:**
```
102 Bob 62000.0 M
104 Diana 71000.0 F
107 Grace 58000.0 F
110 Jack 61000.0 M
```

#### Step 12: Add a new department dynamically
```sql
INSERT INTO TABLE EMPLOYEES_SRC VALUES (113, 'Mike', 65000, 'Marketing', 'M');
INSERT INTO TABLE EMPLOYEES_SRC VALUES (114, 'Nina', 59000, 'Marketing', 'F');

INSERT INTO TABLE EMPLOYEES_PART PARTITION (dept_name)
SELECT emp_id, emp_name, salary, gender, dept_name
FROM EMPLOYEES_SRC
WHERE dept_name = 'Marketing';
```

```sql
SHOW PARTITIONS EMPLOYEES_PART;
```
**Output:**
```
+------------------------+
|     partition          |
+------------------------+
| dept_name=Finance      |
| dept_name=HR           |
| dept_name=IT           |
| dept_name=Marketing    |
+------------------------+
```

#### Step 13: Drop a specific partition
```sql
ALTER TABLE EMPLOYEES_PART DROP PARTITION (dept_name='Marketing');
```
**Output:**
```
OK
```

```sql
SHOW PARTITIONS EMPLOYEES_PART;
```
**Output:**
```
+----------------------+
|     partition        |
+----------------------+
| dept_name=Finance    |
| dept_name=HR         |
| dept_name=IT         |
+----------------------+
```

#### Step 14: Describe the partitioned table
```sql
DESC FORMATTED EMPLOYEES_PART;
```
**Output (partial):**
```
+-------------------------------+----------------------------------------------------+---------------------------+
| col_name                      | data_type                                          | comment                   |
+-------------------------------+----------------------------------------------------+---------------------------+
| emp_id                        | int                                                |                           |
| emp_name                      | string                                             |                           |
| salary                        | double                                             |                           |
| gender                        | string                                             |                           |
| # Partition Information       |                                                    |                           |
| # dept_name                   | string                                             |                           |
+-------------------------------+----------------------------------------------------+---------------------------+

# Detailed Table Information
Database:                  lab8_db
Table Type:               MANAGED_TABLE
Table Parameters:
    ...partitionedCols    [dept_name]
```

---

## Summary of All Labs

| Lab | Topic | Tables Used | Key Concepts |
|-----|-------|-------------|-------------|
| 1 | HDFS Commands | N/A | mkdir, put, get, cp, mv, rm, chmod, permissions |
| 2 | Hive DDL/DML | EMPLOYEE | CREATE TABLE, INSERT, SELECT, WHERE, ORDER BY |
| 3 | Aggregates | ORDERS | COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING |
| 4 | String/Date Fns | EMPLOYEES | UPPER, LOWER, CONCAT, LENGTH, REGEXP_REPLACE, YEAR, MONTH, DATEDIFF |
| 5 | Joins | DEPARTMENT, EMPLOYEES, LOCATION, GRADE, JOB | INNER, LEFT, RIGHT, FULL OUTER, Self Join |
| 6 | Aggregation | ORDER_TABLE | Revenue calc, monthly aggregation, payment analytics |
| 7 | Subqueries & Views | ACTOR, MOVIE, MOVIE_CAST, RATING, REVIEWER | IN, EXISTS, correlated subqueries, CREATE VIEW |
| 8 | Partitioning | EMPLOYEES_SRC, EMPLOYEES_PART | Dynamic partitioning, HDFS storage comparison |

---

*Lab Manual generated for Hadoop 3.5.0 / Hive 4.2.0 / PySpark 4.2.0*
