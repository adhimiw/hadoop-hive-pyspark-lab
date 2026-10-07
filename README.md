# 🚀 Fault-Tolerant Hadoop 3.5 + Hive 4.2 + PySpark 4.1 Lab Setup (2026)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hadoop](https://img.shields.io/badge/Hadoop-3.5.0-red.svg)](https://hadoop.apache.org/)
[![Hive](https://img.shields.io/badge/Hive-4.2.0-yellow.svg)](https://hive.apache.org/)
[![PySpark](https://img.shields.io/badge/PySpark-4.1.2-orange.svg)](https://spark.apache.org/)
[![Java](https://img.shields.io/badge/Java-OpenJDK%2021-blueviolet.svg)](https://openjdk.org/)
[![Platform](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian%20%7C%20CentOS%20%7C%20Fedora-brightgreen.svg)](https://www.linux.org/)

A **turn-key, fault-tolerant Big Data lab environment** tailored for students, researchers, and developers setting up **Apache Hadoop**, **Apache Hive**, and **PySpark** on modern Linux (Ubuntu 22.04/24.04, Debian, CentOS, RHEL, Fedora) and inside virtual machines (VMware, VirtualBox, UTM).

---

## 💡 Why This Project Exists

Setting up Apache Hadoop, Hive, and Spark in **2026** often leads to frustrating roadblocks for university students:
1. **Java 21 Incompatibilities**: Modern distros ship with Java 21, but legacy Hadoop/Hive tools crash without explicit JVM module flags (`--add-opens`) and dumb-terminal options.
2. **VM Shared-Folder Pitfalls**: Running HDFS on VMware (`/mnt/hgfs`) or VirtualBox (`/media/sf_*`) shared folders fails because shared filesystems do not support POSIX locks, causing DataNodes to die on restart.
3. **ClusterID Mismatches**: Formatting NameNodes or restarting VMs leaves DataNodes in `Incompatible clusterIDs` error state.
4. **Derby Lock Crashes**: Hive metastore crashes leave stale `db.lck` and `dbex.lck` locks behind, blocking subsequent starts.
5. **Python PEP 668**: Modern Ubuntu blocks direct `pip install` with externally managed environment errors.

**This repository automates every step and self-heals against common failures.**

---

## 📦 What's Included

```
hadoop-hive-pyspark-lab/
├── setup.sh                     # Automated fault-tolerant installer (apt/dnf/yum)
├── start-services.sh            # Service manager (start, stop, status, restart, heal)
├── copy-to-home.sh              # Guards against VM shared-folder corruption
├── fix-hive.sh                  # Interactive/automated repair utility
├── config/                      # Clean configuration templates
│   ├── core-site.xml            # HDFS default FS & persistent tmp paths
│   ├── hdfs-site.xml            # Single-node replication & storage paths
│   └── hive-site.xml            # Metastore & HiveServer2 configs
├── bin/                         # Test & verification suites
│   ├── files.sh                 # Version pins & Apache mirror endpoints
│   ├── run_all_tests.sh         # Complete test orchestrator
│   ├── test_integration.py     # PySpark ↔ Hive Metastore end-to-end test
│   ├── test_csv_local_hdfs.py  # Local & HDFS ingestion test
│   ├── test_beeline.py         # HiveServer2 (beeline) & PySpark catalog sharing
│   └── test_faults.sh          # Fault recovery unit tests
├── labs/                        # 8 Complete Lab Exercises & Manual
│   ├── Hadoop_Hive_Lab_Manual.md# Comprehensive laboratory manual
│   ├── lab1_hdfs_commands.sh    # HDFS file manipulation commands
│   ├── lab2_hive_employee.sql   # DDL & basic DML
│   ├── lab3_hive_orders.sql     # Filtering and transformations
│   ├── lab4_hive_string_date.sql# String and Date built-in functions
│   ├── lab5_hive_joins.sql      # Inner, Outer, Left, Right joins
│   ├── lab6_hive_aggregate.sql  # Aggregations & GROUP BY
│   ├── lab7_hive_subqueries.sql # Nested subqueries
│   └── lab8_hive_partition.sql  # Partitioning and bucketing
├── datasets/                    # Sample datasets for practice
│   ├── housing_prices.csv
│   ├── iot_sensor_telemetry.json
│   ├── Retail-Store-Sales.csv
│   └── Salary_Data.csv
├── notebooks/                   # Interactive Jupyter notebooks
│   ├── hive_spark_pyspark_demo.ipynb
│   └── hive_spark_pyspark_demo_executed.ipynb
└── docs/                        # Additional integration guides
    └── mongodb_spark_guide.md   # MongoDB Spark Connector offline setup
```

---

## ⚡ Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/adhimiw/hadoop-hive-pyspark-lab.git
cd hadoop-hive-pyspark-lab
```

> **Note for VMware / VirtualBox Users:**
> If you are running inside a shared folder (e.g. `/mnt/hgfs/...`), copy to local storage first:
> ```bash
> ./copy-to-home.sh
> cd ~/hadoop-lab
> ```

### 2. Run the Installer
Run the installer with `sudo`. It detects your distribution (`apt`, `dnf`, or `yum`), installs OpenJDK 21, downloads and extracts Apache Hadoop & Hive (with automatic mirror fallbacks), configures environment variables in `~/.bashrc`, initializes the metastore, sets up a systemd service, and runs all verification tests:

```bash
sudo ./setup.sh
```

### 3. Verify Your Services
Check that all 4 lab services are healthy:
```bash
./start-services.sh status
```

You should see:
```text
✅ NameNode (port 9000)
✅ DataNode (live and registered)
✅ Hive Metastore (port 9083)
✅ HiveServer2 (port 10000)
```

---

## 🔌 Connecting to Services

### Unified Catalog: PySpark + Hive Metastore
Both **HiveServer2** (`beeline`) and **PySpark** connect directly to the Thrift metastore on port `9083`, giving you a shared catalog.

#### 1. Via Python / PySpark
```python
from pyspark.sql import SparkSession

spark = (SparkSession.builder
    .appName("Demo")
    .config("spark.sql.catalogImplementation", "hive")
    .config("spark.hadoop.hive.metastore.uris", "thrift://localhost:9083")
    .enableHiveSupport()
    .getOrCreate())

# Query Hive tables directly in Spark:
spark.sql("SHOW DATABASES").show()
```

#### 2. Via Beeline (Hive CLI)
```bash
beeline -u jdbc:hive2://localhost:10000 -n $USER
```
```sql
SHOW DATABASES;
CREATE TABLE demo_tbl (id INT, name STRING) STORED AS PARQUET;
```

---

## 🌐 Web Interfaces & Ports

| Port | Component | Web UI / Access |
|:---:|:---|:---|
| **9870** | HDFS NameNode | `http://localhost:9870` |
| **9864** | HDFS DataNode | `http://localhost:9864` |
| **9000** | HDFS IPC / RPC | `hdfs://localhost:9000` |
| **9083** | Hive Metastore | `thrift://localhost:9083` |
| **10000** | HiveServer2 | `jdbc:hive2://localhost:10000` |
| **10002** | HiveServer2 Web UI | `http://localhost:10002` |

---

## 🛠️ Management & Self-Healing

The included [`start-services.sh`](start-services.sh) and [`fix-hive.sh`](fix-hive.sh) scripts provide self-healing features:

| Command | Action |
|:---|:---|
| `./start-services.sh status` | Check service health and listening ports |
| `./start-services.sh start` | Start all services with automatic DataNode clusterID healing |
| `./start-services.sh stop` | Gracefully shut down all Hadoop and Hive daemons |
| `./start-services.sh restart` | Restart all daemons |
| `./start-services.sh heal` | Fix DataNode `Incompatible clusterIDs` mismatch |
| `./start-services.sh diagnose` | Run comprehensive system diagnostic checks |
| `bash fix-hive.sh` | Interactive Hive & HDFS repair |
| `bash fix-hive.sh --full` | Clean slate: wipe and reinitialize Derby & HDFS schemas |

---

## 🧪 Testing Your Installation

Verify the complete stack with:
```bash
bash bin/run_all_tests.sh
```

Or run individual tests:
```bash
# Test PySpark ↔ Hive integration
python3 bin/test_integration.py

# Test CSV read/write to local filesystem & HDFS
python3 bin/test_csv_local_hdfs.py

# Test Beeline (HiveServer2) queries and PySpark catalog share
python3 bin/test_beeline.py

# Test fault recovery mechanisms
bash bin/test_faults.sh
```

---

## 📚 Laboratory Curriculum

Check out [`labs/Hadoop_Hive_Lab_Manual.md`](labs/Hadoop_Hive_Lab_Manual.md) for step-by-step exercises:
- **Lab 1**: Fundamental HDFS commands (`-mkdir`, `-put`, `-cat`, `-cp`, `-rm`, `-chmod`)
- **Lab 2**: Hive Employee table DDL & queries
- **Lab 3**: Orders processing and date transformations
- **Lab 4**: Built-in string & date operations
- **Lab 5**: Multi-table Joins (Inner, Left, Right, Full Outer)
- **Lab 6**: Aggregate functions and groupings
- **Lab 7**: Correlated & non-correlated subqueries
- **Lab 8**: Dynamic partitioning and bucketing

---

## 📄 License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute it for academic or personal learning!
