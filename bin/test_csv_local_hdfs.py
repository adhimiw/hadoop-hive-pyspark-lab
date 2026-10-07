#!/usr/bin/env python3
"""Test CSV ingestion two ways: from the LOCAL filesystem and from HDFS.
Proves the 'upload CSV from local' and 'upload CSV from hadoop' flows end to end,
including landing it in a Hive table. Exit 0 = all checks pass."""
import os, subprocess, sys, tempfile

LOCAL_CSV = os.path.join(tempfile.gettempdir(), "people.csv")
HDFS_DIR  = "/user/%s/csvtest" % os.environ.get("USER", "hadoop")
HDFS_CSV  = HDFS_DIR + "/people.csv"
ROWS = [("Alice", 30, "NYC"), ("Bob", 25, "LA"), ("Carol", 35, "SF"), ("Dan", 28, "NYC")]
EXPECTED = len(ROWS)

def sh(cmd):
    print("  $ " + cmd)
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def main():
    # 1. make a local CSV
    with open(LOCAL_CSV, "w") as f:
        f.write("name,age,city\n" + "\n".join(f"{n},{a},{c}" for n, a, c in ROWS) + "\n")
    print(f"Local CSV written: {LOCAL_CSV}")

    # 2. put it into HDFS
    sh(f"hdfs dfs -mkdir -p {HDFS_DIR}")
    sh(f"hdfs dfs -rm -f {HDFS_CSV}")
    r = sh(f"hdfs dfs -put -f {LOCAL_CSV} {HDFS_CSV}")
    if r.returncode != 0:
        print("FAIL: hdfs put failed\n" + r.stderr); return 1
    ls = sh(f"hdfs dfs -ls {HDFS_DIR}")
    print(ls.stdout.strip())

    from pyspark.sql import SparkSession
    spark = (SparkSession.builder.appName("CSVTest")
             .config("spark.sql.catalogImplementation", "hive")
             .config("spark.sql.hive.metastore.version", "4.1.0")
             .config("spark.sql.hive.metastore.jars", "/opt/hive/lib/*")
             .config("spark.hadoop.hive.metastore.uris", "thrift://localhost:9083")
             .enableHiveSupport().getOrCreate())
    spark.sparkContext.setLogLevel("ERROR")
    spark.sql("CREATE DATABASE IF NOT EXISTS demo_db")
    spark.sql("USE demo_db")
    fails = 0

    # 3. read CSV FROM LOCAL, land in Hive
    print("\n[A] CSV from LOCAL filesystem")
    dfl = (spark.read.option("header", True).option("inferSchema", True)
           .csv("file://" + LOCAL_CSV))
    dfl.show()
    n_local = dfl.count()
    print(f"  local rows = {n_local} (expected {EXPECTED})")
    fails += (n_local != EXPECTED)
    dfl.write.mode("overwrite").saveAsTable("people_from_local")
    n_tbl_local = spark.table("people_from_local").count()
    print(f"  hive table people_from_local rows = {n_tbl_local}")
    fails += (n_tbl_local != EXPECTED)

    # 4. read CSV FROM HDFS, land in Hive
    print("\n[B] CSV from HDFS")
    dfh = (spark.read.option("header", True).option("inferSchema", True)
           .csv("hdfs://localhost:9000" + HDFS_CSV))
    dfh.show()
    n_hdfs = dfh.count()
    print(f"  hdfs rows = {n_hdfs} (expected {EXPECTED})")
    fails += (n_hdfs != EXPECTED)
    dfh.write.mode("overwrite").saveAsTable("people_from_hdfs")
    n_tbl_hdfs = spark.table("people_from_hdfs").count()
    print(f"  hive table people_from_hdfs rows = {n_tbl_hdfs}")
    fails += (n_tbl_hdfs != EXPECTED)

    # 5. an aggregation over the HDFS-loaded table (real operation)
    print("\n[C] GROUP BY on HDFS-loaded table")
    agg = spark.sql("SELECT city, COUNT(*) c, ROUND(AVG(age),1) avg_age "
                    "FROM people_from_hdfs GROUP BY city ORDER BY c DESC")
    agg.show()
    nyc = [r for r in agg.collect() if r["city"] == "NYC"]
    fails += (not nyc or nyc[0]["c"] != 2)   # Alice + Dan in NYC

    # 6. local vs hdfs must agree
    print("\n[D] local == hdfs consistency")
    same = sorted(dfl.collect()) == sorted(dfh.collect())
    print(f"  identical rows: {same}")
    fails += (not same)

    spark.stop()
    if fails == 0:
        print("\n✅ CSV TESTS PASSED — local + HDFS ingestion, Hive tables, aggregation all correct")
        return 0
    print(f"\n❌ CSV TESTS FAILED: {fails} check(s) failed")
    return 1

if __name__ == "__main__":
    sys.exit(main())
