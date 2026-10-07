#!/usr/bin/env bash
set -o pipefail

# ═══════════════════════════════════════════════════════════════════
# start-services.sh — start / stop / status / heal for HDFS + Hive
#
#   ./start-services.sh          # status
#   ./start-services.sh start    # start all (with DataNode auto-heal)
#   ./start-services.sh stop
#   ./start-services.sh restart
#   ./start-services.sh heal     # force DataNode clusterID repair
#   ./start-services.sh diagnose # print diagnostics + common fixes
#
# Fault tolerance:
#   * Kills stale/orphan processes before starting (port conflicts).
#   * Cleans Derby lock files after crash/reboot.
#   * DataNode clusterID auto-heal on every start attempt.
#   * Metastore schema verification + auto-upgrade on failure.
#   * HDFS directory creation + permission fix.
#   * Works from bare shell, setup.sh, AND systemd (no ~/.bashrc needed).
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
# If logs/ isn't writable by whoever is running this (e.g. it was created
# root-owned by a sudo'd setup.sh, and we're now the plain user), the metastore
# nohup redirect would fail before exec and the service silently never starts.
# Fall back to a dir we can definitely write instead of dying.
if ! ( : > "$LOG_DIR/.wtest" ) 2>/dev/null; then
    LOG_DIR="${HOME}/.hadoop-lab-logs"
    mkdir -p "$LOG_DIR"
fi
rm -f "$LOG_DIR/.wtest" 2>/dev/null || true

# ────────── environment (override via env before calling) ──────────
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export HIVE_HOME="${HIVE_HOME:-/opt/hive}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}"
if [[ -z "${JAVA_HOME:-}" ]]; then
    _jb=$(readlink -f "$(command -v java 2>/dev/null)" 2>/dev/null)
    [[ -n "$_jb" ]] && export JAVA_HOME="${_jb%/bin/java}"
fi
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$HOME/.local/bin:$PATH"
# -Dorg.jline.terminal.provider=dumb: Hive 4.2 beeline's JLine is Java-21-preview
# compiled and won't load otherwise. Harmless for the HDFS/Hive daemons.
export HADOOP_OPTS="${HADOOP_OPTS:---add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED -Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true}"
export HADOOP_CLIENT_OPTS="$HADOOP_OPTS"
# Hadoop daemons log to $HADOOP_HOME/logs (/opt/hadoop/logs) by default. If /opt
# is root-owned (sudo install), the user-run daemons can't write there and die.
# Point their logs at the same writable LOG_DIR so ownership never blocks them.
export HADOOP_LOG_DIR="${HADOOP_LOG_DIR:-$LOG_DIR/hadoop}"
mkdir -p "$HADOOP_LOG_DIR" 2>/dev/null || true

DN_DATA_DIR="${HOME}/hdfs/datanode"   # matches hdfs-site.xml {{HDFS_DIR}}/datanode
HIVE_DATA_DIR="${HOME}/hive"           # matches hive-site.xml {{HIVE_DATA_DIR}}

log()  { echo -e "[$(date '+%H:%M:%S')] $*"; }
ok()   { log "✅ $*"; }
warn() { log "⚠  $*"; }
fail() { log "❌ $*"; exit 1; }

# port_listening: ss first (iproute2 is on every modern distro incl. minimal
# CentOS); lsof second (often NOT installed on CentOS). Without this, service
# checks silently fail on CentOS where lsof is absent.
port_listening() {
    local p="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | grep -qE ":$p([^0-9]|$)" && return 0
    fi
    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$p" -sTCP:LISTEN 2>/dev/null | grep -q LISTEN && return 0
    fi
    return 1
}

datanode_up()  { hdfs dfsadmin -report 2>/dev/null | grep -qE "Live datanodes \([1-9][0-9]*\)"; }
namenode_up()  { hdfs dfsadmin -report 2>/dev/null | grep -q "Configured Capacity"; }
metastore_up() { port_listening 9083; }
hs2_up()       { port_listening 10000; }

# ══════════════════════════════════════════════════════════════════
# Fault tolerance: kill stale processes before starting
#   After a crash/reboot, orphan Java processes can hold ports 9000/9083/10000
#   or lock Derby database files. Kill them cleanly before we start fresh.
# ══════════════════════════════════════════════════════════════════
kill_stale_processes() {
    local killed=0

    # Kill orphan Hive Metastore (holds port 9083 + Derby lock)
    if metastore_up; then
        local mpid
        mpid=$(lsof -tiTCP:9083 -sTCP:LISTEN 2>/dev/null | head -1)
        if [[ -n "$mpid" ]]; then
            warn "Killing stale Metastore process (PID $mpid on port 9083)"
            kill "$mpid" 2>/dev/null; sleep 2
            kill -9 "$mpid" 2>/dev/null || true
            killed=$((killed+1))
        fi
    fi

    # Kill orphan HiveServer2 (holds port 10000)
    if hs2_up; then
        local hpid
        hpid=$(lsof -tiTCP:10000 -sTCP:LISTEN 2>/dev/null | head -1)
        if [[ -n "$hpid" ]]; then
            warn "Killing stale HiveServer2 process (PID $hpid on port 10000)"
            kill "$hpid" 2>/dev/null; sleep 2
            kill -9 "$hpid" 2>/dev/null || true
            killed=$((killed+1))
        fi
    fi

    # Kill any stray Hadoop daemons by name
    local stray
    stray=$(pgrep -f 'org.apache.hadoop.hdfs.server namenode' 2>/dev/null | head -1)
    if [[ -n "$stray" ]] && ! namenode_up; then
        warn "Killing stale NameNode process (PID $stray)"
        kill "$stray" 2>/dev/null; sleep 1
        kill -9 "$stray" 2>/dev/null || true
        killed=$((killed+1))
    fi

    stray=$(pgrep -f 'org.apache.hadoop.hdfs.server datanode' 2>/dev/null | head -1)
    if [[ -n "$stray" ]] && ! datanode_up; then
        warn "Killing stale DataNode process (PID $stray)"
        kill "$stray" 2>/dev/null; sleep 1
        kill -9 "$stray" 2>/dev/null || true
        killed=$((killed+1))
    fi

    (( killed > 0 )) && log "Killed $killed stale process(es)" || true
}

# ══════════════════════════════════════════════════════════════════
# Fault tolerance: clean Hadoop in_use.lock files after crash/reboot
#   Hadoop NameNode and DataNode create in_use.lock files in their storage
#   directories. After a crash/reboot these persist and prevent startup with
#   "Another instance of Hadoop is running" or similar errors. Safe to delete
#   when no Hadoop daemons are running.
# ══════════════════════════════════════════════════════════════════
clean_hadoop_locks() {
    local cleaned=0
    local hdfs_dir="${HOME}/hdfs"

    # NameNode in_use.lock
    local nn_lock="${hdfs_dir}/namenode/in_use.lock"
    if [[ -f "$nn_lock" ]]; then
        warn "Removing stale NameNode lock: $nn_lock"
        rm -f "$nn_lock" 2>/dev/null || true
        cleaned=$((cleaned+1))
    fi

    # DataNode in_use.lock
    local dn_lock="${hdfs_dir}/datanode/in_use.lock"
    if [[ -f "$dn_lock" ]]; then
        warn "Removing stale DataNode lock: $dn_lock"
        rm -f "$dn_lock" 2>/dev/null || true
        cleaned=$((cleaned+1))
    fi

    # Any other .lock files in hdfs dirs (safety net)
    local other_locks
    other_locks=$(find "$hdfs_dir" -name "*.lock" 2>/dev/null | wc -l)
    if (( other_locks > 0 )); then
        warn "Removing $other_locks additional stale lock file(s) in $hdfs_dir"
        find "$hdfs_dir" -name "*.lock" -delete 2>/dev/null || true
        cleaned=$((cleaned+other_locks))
    fi

    (( cleaned > 0 )) && log "Removed $cleaned Hadoop lock file(s)" || true
}

# ══════════════════════════════════════════════════════════════════
# Fault tolerance: clean Derby lock files after crash/reboot
#   Derby creates a .lck file alongside metastore_db/. After a crash the
#   lock persists and Metastore fails with "Another instance of Derby may
#   have already booted the database". Safe to delete when nothing is running.
# ══════════════════════════════════════════════════════════════════
clean_derby_locks() {
    local db_dir="${HIVE_DATA_DIR}/metastore_db"
    [[ -d "$db_dir" ]] || return 0

    local lock_count
    lock_count=$(find "$db_dir" -name "*.lck" 2>/dev/null | wc -l)
    if (( lock_count > 0 )); then
        warn "Found $lock_count stale Derby lock file(s) — removing"
        find "$db_dir" -name "*.lck" -delete 2>/dev/null || true
    fi

    # Also clean the service log .lck files
    find "$LOG_DIR" -name "*.lck" -delete 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# Fault tolerance: repair a DataNode that refuses to register
#   After a VM restart / re-format the DataNode's VERSION file can carry a
#   stale clusterID -> "Incompatible clusterIDs" -> DataNode exits. Wiping
#   the datanode storage lets it re-register against the current NameNode.
#   Data is replicated x1 on a single node so this is the accepted recovery.
# ══════════════════════════════════════════════════════════════════
heal_datanode() {
    datanode_up && return 1   # healthy already — never wipe a live datanode
    local dnlog
    dnlog=$(ls -t "$HADOOP_LOG_DIR"/*datanode*.log "$HADOOP_HOME"/logs/*datanode*.log 2>/dev/null | head -1)
    # only inspect RECENT lines so a stale historical error can't trigger a wipe
    if [[ -n "$dnlog" ]] && tail -n 300 "$dnlog" | grep -qiE "Incompatible clusterIDs|Invalid dfs.datanode.data.dir|Cannot lock storage|already locked"; then
        warn "DataNode storage is stale/locked — auto-healing (wiping $DN_DATA_DIR)"
        hdfs --daemon stop datanode 2>/dev/null || true
        pkill -f 'DataNode' 2>/dev/null || true
        sleep 2
        rm -rf "${DN_DATA_DIR:?}/"* 2>/dev/null || true
        hdfs --daemon start datanode 2>/dev/null || true
        sleep 4
        return 0
    fi
    return 1
}

# ══════════════════════════════════════════════════════════════════
# Fault tolerance: verify + repair Hive metastore schema
#   After a version upgrade the schema can be incompatible. schematool
#   -upgradeSchema handles this. On failure, we suggest a full reset.
# ══════════════════════════════════════════════════════════════════
verify_metastore_schema() {
    local info
    info=$(schematool -dbType derby -info 2>&1)
    if echo "$info" | grep -q "schema version"; then
        local ver
        ver=$(echo "$info" | grep "schema version" | head -1)
        ok "Metastore schema: $ver"
        return 0
    fi
    warn "Metastore schema check failed — attempting upgrade…"
    if schematool -dbType derby -upgradeSchema 2>&1 | tee -a "$LOG_DIR/metastore.log"; then
        ok "Metastore schema upgraded successfully"
        return 0
    fi
    warn "Schema upgrade failed. Run manually:"
    warn "  schematool -dbType derby -upgradeSchema"
    warn "  Or for a full reset: schematool -dbType derby -dropSchema && schematool -dbType derby -initSchema"
    return 1
}

# ══════════════════════════════════════════════════════════════════
# Ensure HDFS directories for Hive warehouse
# ══════════════════════════════════════════════════════════════════
ensure_hdfs_dirs() {
    hdfs dfsadmin -safemode leave 2>/dev/null || true
    hadoop fs -mkdir -p /user 2>/dev/null || true
    hadoop fs -mkdir -p /user/hive/warehouse 2>/dev/null || true
    hadoop fs -mkdir -p /user/hive/external 2>/dev/null || true
    hadoop fs -chmod -R 777 /user/hive/warehouse 2>/dev/null || true
    hadoop fs -chmod -R 777 /user/hive/external 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# Diagnose — print everything useful for debugging
# ══════════════════════════════════════════════════════════════════
diagnose() {
    echo "═══ Hadoop Lab Diagnostics ═══"
    echo ""
    echo "── Java ──"
    java -version 2>&1 | head -1
    echo "JAVA_HOME=${JAVA_HOME:-<not set>}"
    echo ""
    echo "── Ports ──"
    for p in 9000 9870 9864 9083 10000; do
        if port_listening "$p"; then
            echo "  ✅ Port $p — LISTENING"
        else
            echo "  ❌ Port $p — NOT listening"
        fi
    done
    echo ""
    echo "── Processes ──"
    ps aux 2>/dev/null | grep -E 'NameNode|DataNode|HiveServer2|metastore' | grep -v grep || echo "  (none)"
    echo ""
    echo "── HDFS ──"
    hdfs dfsadmin -report 2>/dev/null | head -15 || echo "  (NameNode unreachable)"
    echo ""
    echo "── HDFS /user/hive ──"
    hdfs dfs -ls -R /user/hive/ 2>/dev/null || echo "  (cannot list)"
    echo ""
    echo "── Derby locks ──"
    local locks
    locks=$(find "${HIVE_DATA_DIR}/metastore_db" -name "*.lck" 2>/dev/null | wc -l)
    echo "  Derby .lck files: $locks"
    echo ""
    echo "── Hadoop locks ──"
    local nn_lock dn_lock other_locks
    [[ -f "${HOME}/hdfs/namenode/in_use.lock" ]] && nn_lock="YES" || nn_lock="no"
    [[ -f "${HOME}/hdfs/datanode/in_use.lock" ]] && dn_lock="YES" || dn_lock="no"
    other_locks=$(find "${HOME}/hdfs" -name "*.lock" 2>/dev/null | wc -l)
    echo "  NameNode in_use.lock: $nn_lock"
    echo "  DataNode in_use.lock: $dn_lock"
    echo "  Total .lock files in hdfs/: $other_locks"
    echo ""
    echo "── Recent logs ──"
    for f in "$LOG_DIR"/metastore.log "$LOG_DIR"/hiveserver2.log "$HADOOP_LOG_DIR"/*datanode*.log; do
        if [[ -f "$f" ]]; then
            echo "  $(basename "$f") (last 5 lines):"
            tail -5 "$f" 2>/dev/null | sed 's/^/    /'
            echo ""
        fi
    done
    echo "── Common fixes ──"
    echo "  Hadoop locks:  rm -f ~/hdfs/namenode/in_use.lock ~/hdfs/datanode/in_use.lock"
    echo "  Derby lock:    rm -f ~/hive/metastore_db/*.lck"
    echo "  DataNode:      bash start-services.sh heal"
    echo "  Full reset:    bash start-services.sh stop; rm -rf ~/hdfs/datanode/*; bash start-services.sh start"
    echo "  Schema reset:  schematool -dbType derby -dropSchema && schematool -dbType derby -initSchema"
    echo "  Hive fix:      bash fix-hive.sh"
}

# ══════════════════════════════════════════════════════════════════
# START
# ══════════════════════════════════════════════════════════════════
start_all() {
    [[ -x "$HADOOP_HOME/bin/hdfs" ]] || fail "Hadoop not found at $HADOOP_HOME (run setup.sh first)"

    # ── Step 0: clean slate (kill orphans + remove ALL stale locks) ──
    kill_stale_processes
    clean_hadoop_locks     # removes in_use.lock that block NameNode/DataNode startup
    clean_derby_locks      # removes Derby .lck that block Metastore startup

    # ── Step 1: HDFS ──
    log "Starting HDFS NameNode…"
    hdfs --daemon start namenode 2>/dev/null || true
    sleep 3
    log "Starting HDFS DataNode…"
    hdfs --daemon start datanode 2>/dev/null || true
    sleep 4

    # Retry loop: heal + restart the DataNode up to 3 times.
    local tries=0
    while ! datanode_up && (( tries < 3 )); do
        heal_datanode || { hdfs --daemon start datanode 2>/dev/null || true; sleep 4; }
        tries=$((tries+1))
    done

    if datanode_up; then ok "HDFS DataNode connected"
    else warn "DataNode still down — see $HADOOP_LOG_DIR/*datanode*.log"; fi

    # ── Step 2: HDFS directories ──
    ensure_hdfs_dirs

    # ── Step 3: Hive Metastore ──
    log "Starting Hive Metastore…"
    if ! metastore_up; then
        nohup hive --service metastore > "${LOG_DIR}/metastore.log" 2>&1 &
        echo "$!" > "${LOG_DIR}/metastore.pid"
        # wait up to ~40s for the metastore thrift port
        local i=0; while ! metastore_up && (( i < 20 )); do sleep 2; i=$((i+1)); done
    fi
    if metastore_up; then
        ok "Hive Metastore up (9083)"
        # Verify schema is healthy (logs warning if upgrade needed)
        verify_metastore_schema 2>/dev/null || true
    else
        warn "Metastore not up — see ${LOG_DIR}/metastore.log"
        warn "Try: bash fix-hive.sh"
    fi

    # ── Step 4: HiveServer2 ──
    log "Starting HiveServer2 (beeline endpoint)…"
    if ! hs2_up; then
        nohup hive --service hiveserver2 > "${LOG_DIR}/hiveserver2.log" 2>&1 &
        echo "$!" > "${LOG_DIR}/hiveserver2.pid"
        # HS2 is slow to open port 10000 — wait up to ~90s
        local j=0; while ! hs2_up && (( j < 45 )); do sleep 2; j=$((j+1)); done
    fi
    hs2_up && ok "HiveServer2 up (10000)" || warn "HiveServer2 not up yet — see ${LOG_DIR}/hiveserver2.log"

    status_all
}

stop_all() {
    log "Stopping HiveServer2…"
    [[ -f "${LOG_DIR}/hiveserver2.pid" ]] && { kill "$(cat "${LOG_DIR}/hiveserver2.pid")" 2>/dev/null; rm -f "${LOG_DIR}/hiveserver2.pid"; }
    pkill -f "hive.*hiveserver2|HiveServer2" 2>/dev/null || true
    log "Stopping Hive Metastore…"
    [[ -f "${LOG_DIR}/metastore.pid" ]] && { kill "$(cat "${LOG_DIR}/metastore.pid")" 2>/dev/null; rm -f "${LOG_DIR}/metastore.pid"; }
    pkill -f "hive.*metastore" 2>/dev/null || true
    log "Stopping HDFS…"
    hdfs --daemon stop datanode 2>/dev/null || true
    hdfs --daemon stop namenode 2>/dev/null || true
    # Clean ALL leftover locks after clean shutdown (prevents issues on next start)
    sleep 2
    clean_hadoop_locks
    clean_derby_locks
    ok "All services stopped"
}

status_all() {
    namenode_up && ok "HDFS NameNode running (port 9000)" || warn "HDFS NameNode NOT running"
    datanode_up && ok "HDFS DataNode connected"            || warn "HDFS DataNode NOT connected"
    metastore_up && ok "Hive Metastore running (port 9083)" || warn "Hive Metastore NOT running"
    hs2_up       && ok "HiveServer2 running (port 10000)"    || warn "HiveServer2 NOT running"
    echo ""
    echo "  NameNode UI (browse HDFS + Hive warehouse): http://localhost:9870"
    echo "  DataNode UI: http://localhost:9864"
    echo "  Beeline: beeline -u 'jdbc:hive2://localhost:10000'"
    echo ""
}

# entrypoint (skipped when sourced by the test harness)
if [[ "${START_SVC_TEST:-}" != "1" ]]; then
case "${1:-status}" in
    start)   start_all ;;
    stop)    stop_all ;;
    restart) stop_all; sleep 2; start_all ;;
    heal)    heal_datanode && ok "heal attempted" || warn "nothing to heal (datanode healthy or no recent error)" ;;
    diagnose) diagnose ;;
    status|*) status_all ;;
esac
fi
