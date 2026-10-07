#!/usr/bin/env python3
"""Beeline (HiveServer2) connectivity + cross-engine catalog test.

Proves:
  1. beeline can connect to HiveServer2 (jdbc:hive2://localhost:10000)
  2. a table created in beeline is visible + writable from PySpark
  3. data written by PySpark is visible from beeline
i.e. beeline and PySpark share ONE Hive metastore.

Beeline is used only for DDL / SHOW / `SELECT *` (fetch tasks — no MR/YARN).
All row inserts go through PySpark's engine. Exit 0 = all checks pass.
"""
import os, subprocess, sys

USER = os.environ.get("USER", "hive")
JDBC = "jdbc:hive2://localhost:10000"
DB, T1, T2 = "demo_db", "xeng_beeline", "xeng_spark"

# Hive 4.2's bundled JLine terminal is compiled with Java-21 preview and won't
# load on a normal JVM ("Preview features are not enabled ... FfmTerminalProvider").
# Force JLine's dumb terminal — fine because beeline runs non-interactively (-e).
_JLINE = "-Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true"
_ENV = dict(os.environ, HADOOP_OPTS=(os.environ.get("HADOOP_OPTS", "") + " " + _JLINE).strip())

def beeline(sql):
    """Run SQL through beeline, return (rc, stdout). tsv2 = parseable."""
    cmd = ["beeline", "-u", JDBC, "-n", USER, "--silent=true",
           "--showHeader=false", "--outputformat=tsv2", "-e", sql]
    p = subprocess.run(cmd, capture_output=True, text=True, env=_ENV)
    return p.returncode, (p.stdout or "") + (p.stderr or "")

def main():
    fails = 0

    # ── 1. connectivity ──
    print("[1] beeline connectivity")
    rc, out = beeline("SHOW DATABASES;")
    if rc != 0:
        print("FAIL: beeline could not connect to HiveServer2\n" + out[-800:]); return 1
    print("  beeline connected. databases:", " ".join(out.split()))
    print("  ✅ HiveServer2 reachable via beeline")

    # ── 2. table created in BEELINE ──
    print("\n[2] create table in beeline (DDL)")
    beeline(f"CREATE DATABASE IF NOT EXISTS {DB};")
    rc, out = beeline(f"DROP TABLE IF EXISTS {DB}.{T1}; "
                      f"CREATE TABLE {DB}.{T1} (id INT, name STRING) STORED AS PARQUET;")
    if rc != 0:
        print("FAIL: beeline CREATE TABLE failed\n" + out[-800:]); return 1
    rc, out = beeline(f"SHOW TABLES IN {DB};")
    print(f"  tables in {DB} (beeline view):", " ".join(out.split()))
    fails += (T1 not in out)
    print(f"  {'✅' if T1 in out else '❌'} {T1} created via beeline")

    # ── Spark session (same metastore) ──
    from pyspark.sql import SparkSession
    spark = (SparkSession.builder.appName("BeelineXEngine")
             .config("spark.sql.catalogImplementation", "hive")
             .config("spark.sql.hive.metastore.version", "4.1.0")
             .config("spark.sql.hive.metastore.jars", "/opt/hive/lib/*")
             .config("spark.hadoop.hive.metastore.uris", "thrift://localhost:9083")
             .enableHiveSupport().getOrCreate())
    spark.sparkContext.setLogLevel("ERROR")

    # ── 3. PySpark sees beeline table, writes to it ──
    print("\n[3] PySpark sees + writes the beeline-created table")
    seen = [r.tableName for r in spark.sql(f"SHOW TABLES IN {DB}").collect()]
    print("  tables (spark view):", seen)
    fails += (T1 not in seen)
    spark.sql(f"INSERT INTO {DB}.{T1} VALUES (1,'alice'),(2,'bob')")
    n = spark.table(f"{DB}.{T1}").count()
    print(f"  spark inserted -> {DB}.{T1} count = {n}")
    fails += (n != 2)

    # ── 4. beeline reads the data PySpark wrote ──
    print("\n[4] beeline reads PySpark-written rows")
    rc, out = beeline(f"SELECT * FROM {DB}.{T1} ORDER BY id;")
    print("  beeline SELECT *:\n   ", out.strip().replace("\n", "\n    "))
    fails += ("alice" not in out or "bob" not in out)
    print(f"  {'✅' if 'alice' in out else '❌'} beeline sees spark-written data")

    # ── 5. reverse: table created in SPARK, read in beeline ──
    print("\n[5] reverse — table created in PySpark, read in beeline")
    spark.sql(f"DROP TABLE IF EXISTS {DB}.{T2}")
    spark.sql(f"CREATE TABLE {DB}.{T2} (k INT, v STRING) STORED AS PARQUET")
    spark.sql(f"INSERT INTO {DB}.{T2} VALUES (7,'seven'),(8,'eight')")
    rc, out = beeline(f"SHOW TABLES IN {DB};")
    fails += (T2 not in out)
    rc, out = beeline(f"SELECT * FROM {DB}.{T2} ORDER BY k;")
    print("  beeline SELECT * on spark table:\n   ", out.strip().replace("\n", "\n    "))
    fails += ("seven" not in out or "eight" not in out)
    print(f"  {'✅' if 'seven' in out else '❌'} spark-created table visible in beeline")

    spark.stop()
    if fails == 0:
        print("\n✅ BEELINE TESTS PASSED — HiveServer2 works, beeline↔PySpark share one metastore")
        return 0
    print(f"\n❌ BEELINE TESTS FAILED: {fails} check(s) failed")
    return 1

if __name__ == "__main__":
    sys.exit(main())
