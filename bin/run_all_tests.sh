#!/usr/bin/env bash
# Run every test suite against a live install. Use after setup or any time.
#   bash bin/run_all_tests.sh
# Self-contained env so it works from a bare shell / systemd too.
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

export JAVA_HOME="${JAVA_HOME:-$(readlink -f "$(command -v java)" | sed 's|/bin/java||')}"
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export HIVE_HOME="${HIVE_HOME:-/opt/hive}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}"
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$HOME/.local/bin:$PATH"
export HADOOP_OPTS="--add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED -Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true"
export HADOOP_CLIENT_OPTS="$HADOOP_OPTS"
export PYSPARK_PYTHON=python3
unset SPARK_HOME PYSPARK_DRIVER_PYTHON PYSPARK_DRIVER_PYTHON_OPTS

# Readiness gate: right after a restart the metastore's port is open but it may
# not be query-ready yet (first Spark connection then fails). Wait until a
# trivial beeline query succeeds, up to ~40s, before running the suite.
echo "Waiting for Hive metastore to be query-ready…"
for i in $(seq 1 20); do
    beeline -u jdbc:hive2://localhost:10000 -n "$USER" --silent=true -e "SHOW DATABASES;" >/dev/null 2>&1 && break
    sleep 2
done

pass=0; fail=0
run() {
    local name="$1"; shift
    echo "═══ $name ═══"
    # retry once on failure — absorbs post-restart warmup transients
    if "$@" || { echo "  … retrying $name after warmup"; sleep 5; "$@"; }; then
        echo "  ✅ $name PASSED"; pass=$((pass+1))
    else echo "  ❌ $name FAILED"; fail=$((fail+1)); fi
    echo ""
}

run "unit: fault-tolerance"  bash        "$DIR/test_faults.sh"
run "PySpark <-> Hive"       python3     "$DIR/test_integration.py"
run "CSV local + HDFS"       python3     "$DIR/test_csv_local_hdfs.py"
run "beeline + cross-engine" python3     "$DIR/test_beeline.py"

echo "════════════════════════════════"
echo "TOTAL: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
