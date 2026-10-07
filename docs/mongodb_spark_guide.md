================================================================================
MongoDB Spark Connector - Local Setup Guide
================================================================================

PURPOSE
=======
Avoid downloading the MongoDB Spark connector on every Spark session start.
Instead, the connector jars are downloaded once and stored locally at:
    /home/mca04/spark-jars/mongo/
then referenced via "spark.jars" (local files, no re-download).

ENVIRONMENT
===========
- PySpark version : 4.1.2 (Scala 2.13)
- Connector      : org.mongodb.spark:mongo-spark-connector_2.13:11.1.0
- MongoDB driver : 5.1.1 (dependency of the connector)
- MongoDB local  : mongodb://localhost:27017/food.types

================================================================================
STEP 1 - Download the jars ONCE
================================================================================

Run these commands in a terminal:

    mkdir -p /home/mca04/spark-jars/mongo && cd /home/mca04/spark-jars/mongo

    JARS="
    org/mongodb/spark/mongo-spark-connector_2.13/11.1.0/mongo-spark-connector_2.13-11.1.0.jar
    org/mongodb/mongodb-driver-sync/5.1.1/mongodb-driver-sync-5.1.1.jar
    org/mongodb/mongodb-driver-core/5.1.1/mongodb-driver-core-5.1.1.jar
    org/mongodb/bson/5.1.1/bson-5.1.1.jar
    org/mongodb/bson-record-codec/5.1.1/bson-record-codec-5.1.1.jar
    "

    for j in $JARS; do
      echo "Downloading $j"
      curl -sfL -O "https://repo1.maven.org/maven2/$j" || echo "FAILED: $j"
    done

Expected files after download:
    bson-5.1.1.jar
    bson-record-codec-5.1.1.jar
    mongodb-driver-core-5.1.1.jar
    mongodb-driver-sync-5.1.1.jar
    mongo-spark-connector_2.13-11.1.0.jar

NOTE:
- The MongoDB driver jars MUST match the version the connector depends on
  (5.1.x for connector 11.1.0). If you upgrade the connector, re-check its
  .pom at:
      https://repo1.maven.org/maven2/org/mongodb/spark/mongo-spark-connector_2.13/
- If your Spark version uses Scala 2.13, use the "_2.13" connector build.

================================================================================
STEP 2 - Use the jars in your PySpark code (no download each run)
================================================================================

Replace "spark.jars.packages" with "spark.jars" pointing at the local jars:

    from pyspark.sql import SparkSession

    jars = ",".join([
        "/home/mca04/spark-jars/mongo/mongo-spark-connector_2.13-11.1.0.jar",
        "/home/mca04/spark-jars/mongo/mongodb-driver-sync-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/mongodb-driver-core-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/bson-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/bson-record-codec-5.1.1.jar",
    ])

    spark = SparkSession.builder.master("local[*]")\
        .appName("mongodb")\
        .config("spark.jars", jars)\
        .config("spark.mongodb.read.connection.uri", "mongodb://localhost:27017/food.types")\
        .config("spark.mongodb.write.connection.uri", "mongodb://localhost:27017/food.types")\
        .getOrCreate()

IMPORTANT - JUPYTER NOTEBOOK (ipynb) USERS:
-------------------------------------------
When pasting into a Jupyter cell, REMOVE the leading indentation from the
top-level lines (from pyspark import, jars =, spark =). The code above is
indented only because it is shown inside this guide.

Top-level code in a Jupyter cell must start at column 0. Paste this instead:

    from pyspark.sql import SparkSession

    jars = ",".join([
        "/home/mca04/spark-jars/mongo/mongo-spark-connector_2.13-11.1.0.jar",
        "/home/mca04/spark-jars/mongo/mongodb-driver-sync-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/mongodb-driver-core-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/bson-5.1.1.jar",
        "/home/mca04/spark-jars/mongo/bson-record-codec-5.1.1.jar",
    ])

    spark = SparkSession.builder.master("local[*]")\
        .appName("mongodb")\
        .config("spark.jars", jars)\
        .config("spark.mongodb.read.connection.uri", "mongodb://localhost:27017/food.types")\
        .config("spark.mongodb.write.connection.uri", "mongodb://localhost:27017/food.types")\
        .getOrCreate()

If you get "IndentationError: unexpected indent" at the first line, it means
the cell still has leading spaces. Un-indent all lines (select all, Shift+Tab,
or Edit > Unindent) and run again.

================================================================================
STEP 3 - Example: reading and writing
================================================================================

    # READ a MongoDB collection into a DataFrame
    df = spark.read.format("mongodb").load()

    # WRITE a DataFrame to a MongoDB collection
    df.write.format("mongodb").mode("overwrite").save()

    # READ a specific collection
    df = (spark.read
          .format("mongodb")
          .option("database", "food")
          .option("collection", "types")
          .load())

    # WRITE to a specific collection
    (df.write
     .format("mongodb")
     .option("database", "food")
     .option("collection", "types")
     .mode("overwrite")
     .save())

    df.show()
    df.printSchema()

================================================================================
ALTERNATIVE - Using spark-submit
================================================================================

If you launch scripts with spark-submit, pass the jars with --jars:

    spark-submit --jars \
      /home/mca04/spark-jars/mongo/mongo-spark-connector_2.13-11.1.0.jar, \
      /home/mca04/spark-jars/mongo/mongodb-driver-sync-5.1.1.jar, \
      /home/mca04/spark-jars/mongo/mongodb-driver-core-5.1.1.jar, \
      /home/mca04/spark-jars/mongo/bson-5.1.1.jar, \
      /home/mca04/spark-jars/mongo/bson-record-codec-5.1.1.jar \
      my_script.py

Or use a comma-separated path on one line (no spaces):
    --jars /home/mca04/spark-jars/mongo/mongo-spark-connector_2.13-11.1.0.jar,/home/mca04/spark-jars/mongo/mongodb-driver-sync-5.1.1.jar,/home/mca04/spark-jars/mongo/mongodb-driver-core-5.1.1.jar,/home/mca04/spark-jars/mongo/bson-5.1.1.jar,/home/mca04/spark-jars/mongo/bson-record-codec-5.1.1.jar

================================================================================
ALTERNATIVE - Global Spark config (optional)
================================================================================

To apply the jars to EVERY session automatically, add to
$SPARK_HOME/conf/spark-defaults.conf (create if missing):

    spark.jars  /home/mca04/spark-jars/mongo/mongo-spark-connector_2.13-11.1.0.jar,/home/mca04/spark-jars/mongo/mongodb-driver-sync-5.1.1.jar,/home/mca04/spark-jars/mongo/mongodb-driver-core-5.1.1.jar,/home/mca04/spark-jars/mongo/bson-5.1.1.jar,/home/mca04/spark-jars/mongo/bson-record-codec-5.1.1.jar

Then your original code (without spark.jars / spark.jars.packages) works directly.

================================================================================
TROUBLESHOOTING
================================================================================

1. "ClassNotFoundException: com.mongodb.spark.connector..."
   -> The connector jar is not on the classpath. Check the "spark.jars" path.

2. "NoSuchMethodError" or version errors from MongoDB driver
   -> Driver jars do not match connector expectations. Keep driver at 5.1.1
      for connector 11.1.0.

3. Connector still downloads when using spark.jars.packages
   -> That is expected. Only "spark.jars" / "--jars" avoids downloading.

4. Cannot connect to MongoDB
   -> Make sure mongod is running:  sudo systemctl start mongod  (or your service)
   -> Verify URI: mongodb://localhost:27017/food.types
      (this URI points at database "food", collection "types")

================================================================================
KEY FILES
================================================================================

- Connector jars       : /home/mca04/spark-jars/mongo/
- This guide           : /home/mca04/spark-jars/mongo/mongodb_spark_guide.txt
================================================================================
