#!/usr/bin/env python3
"""Smoke test: verify PySpark can read/write through Hive Metastore."""
import sys
import traceback

def main():
    try:
        from pyspark.sql import SparkSession
    except ImportError:
        print("FAIL: PySpark is not installed (pip install pyspark)")
        return 1

    spark = None
    try:
        spark = SparkSession.builder \
            .appName("HiveSmokeTest") \
            .config("spark.sql.catalogImplementation", "hive") \
            .config("spark.sql.hive.metastore.version", "4.1.0") \
            .config("spark.sql.hive.metastore.jars", "/opt/hive/lib/*") \
            .config("spark.hadoop.hive.metastore.uris", "thrift://localhost:9083") \
            .enableHiveSupport() \
            .getOrCreate()

        # Test 1: List databases
        dbs = spark.sql("SHOW DATABASES").collect()
        db_names = [row[0] for row in dbs]
        print(f"PASS: Databases: {db_names}")
        if "default" not in db_names:
            print("FAIL: 'default' database not found")
            return 1

        # Test 2: Create table
        spark.sql("CREATE TABLE IF NOT EXISTS smoke_test (id INT, val STRING) USING hive")
        print("PASS: Table created")

        # Test 3: Insert data
        spark.sql("INSERT INTO smoke_test VALUES (1, 'hello'), (2, 'world')")
        print("PASS: Data inserted")

        # Test 4: Query data
        rows = spark.sql("SELECT * FROM smoke_test ORDER BY id").collect()
        values = [(r.id, r.val) for r in rows]
        expected = [(1, "hello"), (2, "world")]
        if values == expected:
            print(f"PASS: Query returned: {values}")
        else:
            print(f"FAIL: Expected {expected}, got {values}")
            return 1

        # Test 5: Cleanup
        spark.sql("DROP TABLE IF EXISTS smoke_test")
        print("PASS: Table dropped")

        print("\n✅ ALL TESTS PASSED — PySpark + Hive integration works!")
        return 0

    except Exception as e:
        print(f"FAIL: {e}")
        traceback.print_exc()
        return 1
    finally:
        if spark is not None:
            spark.stop()

if __name__ == "__main__":
    sys.exit(main())
