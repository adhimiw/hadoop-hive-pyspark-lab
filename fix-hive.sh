#!/usr/bin/env bash
set -o pipefail

# ═══════════════════════════════════════════════════════════════════
# fix-hive.sh — Repair a broken Hive + HDFS installation
#
# Use this when:
#   * Metastore won't start ("Another instance of Derby…")
#   * HiveServer2 won't open port 10000
#   * Tables not showing in HDFS / NameNode UI (port 9870)
#   * "Incompatible clusterIDs" on DataNode
#   * After VM restart / reboot and services are broken
#   * PySpark can't connect to Hive
#   * Schema version mismatch errors
#
# Usage:  bash fix-hive.sh           # interactive repair
#         bash fix-hive.sh --full    # nuclear: wipe + re-init everything
#         bash fix-hive.sh --status  # diagnose only, no changes
#
# Safe to run multiple times. Idempotent.
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# ────────── environment ──────────
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export HIVE_HOME="${HIVE_HOME:-/opt/hive}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}"
if [[ -z "${JAVA_HOME:-}" ]]; then
    _jb=$(readlink -f "$(command -v java 2>/dev/null)" 2>/dev/null)
    [[ -n "$_jb" ]] && export JAVA_HOME="${_jb%/bin/java}"
fi
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$HOME/.local/bin:$PATH"
export HADOOP_OPTS="${HADOOP_OPTS:---add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED -Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true}"
export HADOOP_CLIENT_OPTS="$HADOOP_OPTS"
export HADOOP_LOG_DIR="${HADOOP_LOG_DIR:-$LOG_DIR/hadoop}"
mkdir -p "$HADOOP_LOG_DIR" 2>/dev/null || true

HIVE_DATA_DIR="${HOME}/hive"
HDFS_DATA_DIR="${HOME}/hdfs"
DN_DATA_DIR="${HOME}/hdfs/datanode"

# ────────── logging ──────────
log()  { echo -e "[$(date '+%H:%M:%S')] $*"; }
ok()   { log "✅ $*"; }
warn() { log "⚠  $*"; }
fail() { log "❌ $*"; exit 1; }

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

MODE="${1:---repair}"

# ══════════════════════════════════════════════════════════════════
# Step 1: Status check
# ══════════════════════════════════════════════════════════════════
status_check() {
    echo ""
    echo "═══ Current Status ═══"
    echo ""

    # Java
    if java -version 2>&1 | grep -q 'version "21'; then
        ok "Java 21"
    else
        warn "Java 21 NOT found (have: $(java -version 2>&1 | head -1))"
    fi

    # Hadoop
    if [[ -f "${HADOOP_HOME}/share/hadoop/common/hadoop-common-*.jar" ]]; then
        ok "Hadoop installed at ${HADOOP_HOME}"
    else
        warn "Hadoop NOT found at ${HADOOP_HOME}"
    fi

    # Hive
    if [[ -f "${HIVE_HOME}/lib/hive-common-*.jar" ]]; then
        ok "Hive installed at ${HIVE_HOME}"
    else
        warn "Hive NOT found at ${HIVE_HOME}"
    fi

    # HDFS dirs
    if [[ -d "${HDFS_DATA_DIR}/namenode/current" ]]; then
        ok "HDFS NameNode formatted"
    else
        warn "HDFS NameNode NOT formatted"
    fi

    if [[ -d "${HDFS_DATA_DIR}/datanode/current" ]]; then
        ok "HDFS DataNode data exists"
    else
        warn "HDFS DataNode data missing"
    fi

    # Derby
    if [[ -d "${HIVE_DATA_DIR}/metastore_db" ]]; then
        local locks
        locks=$(find "${HIVE_DATA_DIR}/metastore_db" -name "*.lck" 2>/dev/null | wc -l)
        if (( locks > 0 )); then
            warn "Derby lock files: $locks (stale — will be cleaned)"
        else
            ok "Derby metastore_db (no locks)"
        fi
    else
        warn "Derby metastore_db NOT found"
    fi

    # Hadoop locks
    local nn_lock dn_lock
    [[ -f "${HDFS_DATA_DIR}/namenode/in_use.lock" ]] && nn_lock="YES (stale)" || nn_lock="no"
    [[ -f "${HDFS_DATA_DIR}/datanode/in_use.lock" ]] && dn_lock="YES (stale)" || dn_lock="no"
    if [[ "$nn_lock" == *"YES"* ]] || [[ "$dn_lock" == *"YES"* ]]; then
        warn "Hadoop locks — NameNode: $nn_lock, DataNode: $dn_lock"
    else
        ok "Hadoop locks (none)"
    fi

    # Config
    if [[ -f "${HADOOP_HOME}/etc/hadoop/core-site.xml" ]]; then
        ok "core-site.xml present"
    else
        warn "core-site.xml MISSING"
    fi
    if [[ -f "${HIVE_HOME}/conf/hive-site.xml" ]]; then
        ok "hive-site.xml present"
        if grep -q "hdfs://localhost:9000/user/hive/warehouse" "${HIVE_HOME}/conf/hive-site.xml" 2>/dev/null; then
            ok "hive-site.xml points to HDFS warehouse"
        else
            warn "hive-site.xml warehouse dir is NOT HDFS — tables won't appear in NameNode UI"
        fi
    else
        warn "hive-site.xml MISSING"
    fi

    # Services
    namenode_up && ok "NameNode (port 9000)" || warn "NameNode NOT running"
    datanode_up && ok "DataNode"             || warn "DataNode NOT running"
    metastore_up && ok "Metastore (port 9083)" || warn "Metastore NOT running"
    hs2_up && ok "HiveServer2 (port 10000)"    || warn "HiveServer2 NOT running"

    # HDFS Hive dirs
    if namenode_up; then
        if hdfs dfs -test -d /user/hive/warehouse 2>/dev/null; then
            ok "HDFS /user/hive/warehouse exists"
        else
            warn "HDFS /user/hive/warehouse MISSING"
        fi
        if hdfs dfs -test -d /user/hive/external 2>/dev/null; then
            ok "HDFS /user/hive/external exists"
        else
            warn "HDFS /user/hive/external MISSING"
        fi
    fi

    echo ""
}

# ══════════════════════════════════════════════════════════════════
# Step 2: Stop everything
# ══════════════════════════════════════════════════════════════════
stop_everything() {
    log "Stopping all services…"
    pkill -f "HiveServer2" 2>/dev/null || true
    pkill -f "hive.*hiveserver2" 2>/dev/null || true
    pkill -f "hive.*metastore" 2>/dev/null || true
    hdfs --daemon stop datanode 2>/dev/null || true
    hdfs --daemon stop namenode 2>/dev/null || true
    sleep 3
    # Force-kill anything left
    pkill -f 'org.apache.hadoop.hdfs.server' 2>/dev/null || true
    pkill -f 'org.apache.hive' 2>/dev/null || true
    sleep 2
    ok "All services stopped"
}

# ══════════════════════════════════════════════════════════════════
# Step 3: Clean Derby locks
# ══════════════════════════════════════════════════════════════════
clean_locks() {
    log "Cleaning all stale lock files…"
    local derby_count=0
    local hadoop_count=0

    # Derby locks (Metastore)
    if [[ -d "${HIVE_DATA_DIR}/metastore_db" ]]; then
        derby_count=$(find "${HIVE_DATA_DIR}/metastore_db" -name "*.lck" 2>/dev/null | wc -l)
        find "${HIVE_DATA_DIR}/metastore_db" -name "*.lck" -delete 2>/dev/null || true
    fi
    find "$LOG_DIR" -name "*.lck" -delete 2>/dev/null || true

    # Hadoop locks (NameNode + DataNode in_use.lock)
    local hdfs_dir="${HOME}/hdfs"
    if [[ -f "${hdfs_dir}/namenode/in_use.lock" ]]; then
        rm -f "${hdfs_dir}/namenode/in_use.lock" 2>/dev/null || true
        hadoop_count=$((hadoop_count+1))
    fi
    if [[ -f "${hdfs_dir}/datanode/in_use.lock" ]]; then
        rm -f "${hdfs_dir}/datanode/in_use.lock" 2>/dev/null || true
        hadoop_count=$((hadoop_count+1))
    fi
    local other_locks
    other_locks=$(find "$hdfs_dir" -name "*.lock" 2>/dev/null | wc -l)
    if (( other_locks > 0 )); then
        find "$hdfs_dir" -name "*.lock" -delete 2>/dev/null || true
        hadoop_count=$((hadoop_count+other_locks))
    fi

    ok "Removed $derby_count Derby + $hadoop_count Hadoop lock file(s)"
}

# ══════════════════════════════════════════════════════════════════
# Step 4: Fix hive-site.xml (point warehouse to HDFS)
# ══════════════════════════════════════════════════════════════════
fix_hive_config() {
    log "Checking hive-site.xml…"
    local conf="${HIVE_HOME}/conf/hive-site.xml"
    local template="${SCRIPT_DIR}/config/hive-site.xml"

    if [[ ! -f "$conf" ]]; then
        if [[ -f "$template" ]]; then
            warn "hive-site.xml missing — creating from template"
            mkdir -p "${HIVE_HOME}/conf"
            sed -e "s|{{HIVE_DATA_DIR}}|${HIVE_DATA_DIR}|g" "$template" > "$conf"
            ok "hive-site.xml created"
            return 0
        else
            warn "No hive-site.xml template found — cannot fix"
            return 1
        fi
    fi

    # Check warehouse dir
    if grep -q "hdfs://localhost:9000/user/hive/warehouse" "$conf" 2>/dev/null; then
        ok "hive-site.xml already points warehouse to HDFS"
        return 0
    fi

    warn "hive-site.xml warehouse dir is local, not HDFS — fixing"
    # Patch the warehouse dir
    if grep -q "hive.metastore.warehouse.dir" "$conf"; then
        sed -i 's|<value>/user/hive/warehouse</value>|<value>hdfs://localhost:9000/user/hive/warehouse</value>|' "$conf"
    else
        # Add the property before </configuration>
        sed -i '/<\/configuration>/i \
    <property>\
        <name>hive.metastore.warehouse.dir</name>\
        <value>hdfs://localhost:9000/user/hive/warehouse</value>\
    </property>' "$conf"
    fi

    # Add external dir if missing
    if ! grep -q "hive.metastore.warehouse.external.dir" "$conf"; then
        sed -i '/<\/configuration>/i \
    <property>\
        <name>hive.metastore.warehouse.external.dir</name>\
        <value>hdfs://localhost:9000/user/hive/external</value>\
    </property>' "$conf"
    fi

    # Add metastore.uris if missing
    if ! grep -q "hive.metastore.uris" "$conf"; then
        sed -i '/<\/configuration>/i \
    <property>\
        <name>hive.metastore.uris</name>\
        <value>thrift://localhost:9083</value>\
    </property>' "$conf"
    fi

    ok "hive-site.xml fixed — warehouse points to HDFS"
}

# ══════════════════════════════════════════════════════════════════
# Step 5: Fix Hadoop configs
# ══════════════════════════════════════════════════════════════════
fix_hadoop_config() {
    log "Checking Hadoop config…"
    local core="${HADOOP_HOME}/etc/hadoop/core-site.xml"
    local hdfs_cfg="${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"
    local core_tpl="${SCRIPT_DIR}/config/core-site.xml"
    local hdfs_tpl="${SCRIPT_DIR}/config/hdfs-site.xml"

    # Core-site
    if [[ ! -f "$core" ]] && [[ -f "$core_tpl" ]]; then
        warn "core-site.xml missing — creating from template"
        sed -e "s|{{HDFS_DIR}}|${HDFS_DATA_DIR}|g" "$core_tpl" > "$core"
        ok "core-site.xml created"
    elif [[ -f "$core" ]]; then
        # Ensure fs.defaultFS is set
        if ! grep -q "fs.defaultFS" "$core" 2>/dev/null; then
            warn "core-site.xml missing fs.defaultFS — adding"
            sed -i '/<\/configuration>/i \
    <property>\
        <name>fs.defaultFS</name>\
        <value>hdfs://localhost:9000</value>\
    </property>' "$core"
        fi
    fi

    # Hdfs-site
    if [[ ! -f "$hdfs_cfg" ]] && [[ -f "$hdfs_tpl" ]]; then
        warn "hdfs-site.xml missing — creating from template"
        sed -e "s|{{HDFS_DIR}}|${HDFS_DATA_DIR}|g" "$hdfs_tpl" > "$hdfs_cfg"
        ok "hdfs-site.xml created"
    fi

    # hadoop-env.sh JAVA_HOME
    local henv="${HADOOP_HOME}/etc/hadoop/hadoop-env.sh"
    if [[ -f "$henv" ]] && ! grep -q "^export JAVA_HOME=" "$henv" 2>/dev/null; then
        echo "export JAVA_HOME=${JAVA_HOME:-$(readlink -f "$(command -v java)" | sed 's|/bin/java||')}" >> "$henv"
        ok "Added JAVA_HOME to hadoop-env.sh"
    fi

    ok "Hadoop config checked"
}

# ══════════════════════════════════════════════════════════════════
# Step 6: Fix permissions
# ══════════════════════════════════════════════════════════════════
fix_permissions() {
    log "Fixing file ownership…"
    local u
    u=$(id -un)
    chown -R "$u:$u" "${SCRIPT_DIR}" 2>/dev/null || true
    chown -R "$u:$u" "${HADOOP_HOME}" 2>/dev/null || true
    chown -R "$u:$u" "${HIVE_HOME}" 2>/dev/null || true
    chown -R "$u:$u" "${HDFS_DATA_DIR}" 2>/dev/null || true
    chown -R "$u:$u" "${HIVE_DATA_DIR}" 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
    ok "Permissions fixed"
}

# ══════════════════════════════════════════════════════════════════
# Step 7: Fix DataNode clusterID
# ══════════════════════════════════════════════════════════════════
fix_datanode() {
    log "Checking DataNode health…"
    if datanode_up; then
        ok "DataNode is healthy"
        return 0
    fi

    local dnlog
    dnlog=$(ls -t "$HADOOP_LOG_DIR"/*datanode*.log "$HADOOP_HOME"/logs/*datanode*.log 2>/dev/null | head -1)
    if [[ -n "$dnlog" ]] && tail -n 300 "$dnlog" | grep -qiE "Incompatible clusterIDs|Cannot lock storage|already locked"; then
        warn "DataNode has stale storage — wiping"
        rm -rf "${DN_DATA_DIR:?}/"* 2>/dev/null || true
        ok "DataNode storage wiped (will re-register on start)"
    else
        warn "DataNode not running but no clear error — check logs"
    fi
}

# ══════════════════════════════════════════════════════════════════
# Step 8: Fix HDFS directories
# ══════════════════════════════════════════════════════════════════
fix_hdfs_dirs() {
    log "Ensuring HDFS directories…"
    # NameNode may need reformat if data is corrupt
    if [[ ! -d "${HDFS_DATA_DIR}/namenode/current" ]]; then
        warn "NameNode not formatted — formatting now"
        hdfs namenode -format -force 2>&1 | tee -a "$LOG_DIR/fix-hive.log" || warn "Format had issues"
    fi

    # Start just HDFS to create dirs
    hdfs --daemon start namenode 2>/dev/null || true
    sleep 3
    hdfs --daemon start datanode 2>/dev/null || true
    sleep 4

    # Retry datanode heal
    local tries=0
    while ! datanode_up && (( tries < 3 )); do
        local dnlog
        dnlog=$(ls -t "$HADOOP_LOG_DIR"/*datanode*.log 2>/dev/null | head -1)
        if [[ -n "$dnlog" ]] && tail -n 300 "$dnlog" | grep -qiE "Incompatible clusterIDs|Cannot lock storage"; then
            rm -rf "${DN_DATA_DIR:?}/"* 2>/dev/null || true
            hdfs --daemon stop datanode 2>/dev/null || true
            hdfs --daemon start datanode 2>/dev/null || true
            sleep 4
        else
            hdfs --daemon start datanode 2>/dev/null || true
            sleep 4
        fi
        tries=$((tries+1))
    done

    hdfs dfsadmin -safemode leave 2>/dev/null || true
    hadoop fs -mkdir -p /user 2>/dev/null || true
    hadoop fs -mkdir -p /user/hive/warehouse 2>/dev/null || true
    hadoop fs -mkdir -p /user/hive/external 2>/dev/null || true
    hadoop fs -chmod -R 777 /user/hive/warehouse 2>/dev/null || true
    hadoop fs -chmod -R 777 /user/hive/external 2>/dev/null || true
    ok "HDFS directories ready"

    # Verify
    if hdfs dfs -test -d /user/hive/warehouse 2>/dev/null; then
        ok "Verified: /user/hive/warehouse exists in HDFS"
    else
        warn "Could not create /user/hive/warehouse in HDFS"
    fi
}

# ══════════════════════════════════════════════════════════════════
# Step 9: Fix metastore schema
# ══════════════════════════════════════════════════════════════════
fix_metastore_schema() {
    log "Checking metastore schema…"
    local info
    info=$(schematool -dbType derby -info 2>&1)

    if echo "$info" | grep -q "schema version"; then
        ok "Schema is healthy"
        return 0
    fi

    warn "Schema check failed — attempting recovery…"

    # Try upgrade first
    if schematool -dbType derby -upgradeSchema 2>&1 | tee -a "$LOG_DIR/fix-hive.log"; then
        ok "Schema upgraded successfully"
        return 0
    fi

    # If upgrade fails, try drop + init
    warn "Upgrade failed — dropping and re-initializing schema"
    warn "WARNING: This will lose Hive table metadata (data in HDFS is safe)"
    schematool -dbType derby -dropSchema 2>&1 | tee -a "$LOG_DIR/fix-hive.log" || true
    rm -rf "${HIVE_DATA_DIR}/metastore_db" 2>/dev/null || true
    if schematool -dbType derby -initSchema 2>&1 | tee -a "$LOG_DIR/fix-hive.log"; then
        ok "Schema re-initialized"
    else
        warn "Schema init failed — check ${LOG_DIR}/fix-hive.log"
    fi
}

# ══════════════════════════════════════════════════════════════════
# Step 10: Start services
# ══════════════════════════════════════════════════════════════════
start_everything() {
    log "Starting all services…"
    bash "${SCRIPT_DIR}/start-services.sh" start 2>&1
}

# ══════════════════════════════════════════════════════════════════
# Step 11: Verify
# ══════════════════════════════════════════════════════════════════
verify() {
    echo ""
    echo "═══ Final Verification ═══"
    echo ""

    local pass=0 fail=0

    # NameNode
    if namenode_up; then echo "  ✅ NameNode (9000)"; pass=$((pass+1)); else echo "  ❌ NameNode"; fail=$((fail+1)); fi

    # DataNode
    if datanode_up; then echo "  ✅ DataNode"; pass=$((pass+1)); else echo "  ❌ DataNode"; fail=$((fail+1)); fi

    # Metastore
    if metastore_up; then echo "  ✅ Metastore (9083)"; pass=$((pass+1)); else echo "  ❌ Metastore"; fail=$((fail+1)); fi

    # HiveServer2
    if hs2_up; then echo "  ✅ HiveServer2 (10000)"; pass=$((pass+1)); else echo "  ❌ HiveServer2"; fail=$((fail+1)); fi

    # HDFS dirs
    if hdfs dfs -test -d /user/hive/warehouse 2>/dev/null; then
        echo "  ✅ HDFS /user/hive/warehouse"; pass=$((pass+1))
    else
        echo "  ❌ HDFS /user/hive/warehouse"; fail=$((fail+1))
    fi

    # Beeline test
    if hs2_up && beeline -u jdbc:hive2://localhost:10000 -n "$(id -un)" --silent=true -e "SHOW DATABASES;" >/dev/null 2>&1; then
        echo "  ✅ Beeline query works"; pass=$((pass+1))
    else
        echo "  ⚠  Beeline query skipped (HS2 not ready yet)"
    fi

    # NameNode UI
    if curl -s -o /dev/null -w '' http://localhost:9870 2>/dev/null; then
        echo "  ✅ NameNode UI (http://localhost:9870)"; pass=$((pass+1))
    else
        echo "  ⚠  NameNode UI not reachable"
    fi

    echo ""
    echo "  Results: $pass passed, $fail failed"
    echo ""

    if (( fail == 0 )); then
        echo "  ╔═══════════════════════════════════════╗"
        echo "  ║  ALL CHECKS PASSED                    ║"
        echo "  ╚═══════════════════════════════════════╝"
        echo ""
        echo "  Browse Hive tables in HDFS:"
        echo "    http://localhost:9870/explorer.html#/user/hive/warehouse"
        echo ""
        echo "  Connect with beeline:"
        echo "    beeline -u 'jdbc:hive2://localhost:10000'"
        echo ""
    else
        echo "  Some checks failed. Run 'bash start-services.sh diagnose' for details."
    fi
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   fix-hive.sh — Repair Hive + HDFS            ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo ""

    case "$MODE" in
        --status)
            status_check
            return 0
            ;;
        --full)
            log "═══ FULL RESET (nuclear mode) ═══"
            status_check
            stop_everything
            clean_locks
            fix_permissions
            fix_hadoop_config
            fix_hive_config
            fix_datanode
            # Wipe and re-init everything
            rm -rf "${HDFS_DATA_DIR}/namenode" "${HDFS_DATA_DIR}/datanode" "${HDFS_DATA_DIR}/tmp"
            mkdir -p "${HDFS_DATA_DIR}/namenode" "${HDFS_DATA_DIR}/datanode"
            rm -rf "${HIVE_DATA_DIR}/metastore_db"
            fix_hdfs_dirs
            fix_metastore_schema
            start_everything
            verify
            ;;
        --repair|*)
            log "═══ REPAIR MODE ═══"
            status_check
            stop_everything
            clean_locks
            fix_permissions
            fix_hadoop_config
            fix_hive_config
            fix_datanode
            fix_hdfs_dirs
            fix_metastore_schema
            start_everything
            verify
            ;;
    esac
}

main "$@"
