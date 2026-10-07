# Expected tarballs (sourced by setup.sh)
# Place these files in the setup/ directory before running setup.sh

HADOOP_VER="${HADOOP_VER:-3.5.0}"
HIVE_VER="${HIVE_VER:-4.2.0}"
PYSPARK_VER="${PYSPARK_VER:-4.1.2}"

# Hadoop:  https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VER}/hadoop-${HADOOP_VER}.tar.gz
# Hive:    https://dlcdn.apache.org/hive/hive-${HIVE_VER}/apache-hive-${HIVE_VER}-bin.tar.gz
# PySpark: pip download pyspark==${PYSPARK_VER}  (produces pyspark-${PYSPARK_VER}-py3-none-any.whl)
