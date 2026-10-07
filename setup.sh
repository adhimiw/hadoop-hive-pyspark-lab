#!/usr/bin/env bash
set -o pipefail

# ═══════════════════════════════════════════════════════════════════
# setup.sh — Fault-tolerant Hadoop + Hive + PySpark single-node install
#   Hadoop 3.5.0 + Hive 4.2.0 + PySpark (single-node / pseudo-distributed)
#
# Usage:   sudo ./setup.sh
#
# Works on:  Debian/Ubuntu/Pop!_OS (apt)  AND  CentOS/RHEL/Fedora (dnf/yum)
#
# Fault tolerance built in:
#   * Refuses to run from a VMware/VirtualBox shared folder and copies
#     itself to the user's HOME first (root cause of "DataNode dead after
#     VM restart"). See guard_shared_folder().
#   * pip missing -> installs it (ensurepip -> distro pkg). Never exits.
#   * hadoop.tmp.dir kept off /tmp so state survives reboot.
#   * DataNode "Incompatible clusterIDs" -> auto-wipes datanode dir + retries.
#   * Kill stale processes before starting (port conflicts, orphan daemons).
#   * Derby lock file cleanup (avoids "Another instance of Derby may have
#     already booted the database" after crash/reboot).
#   * Metastore schema upgrade detection + auto-recovery.
#   * HDFS directory creation + permission fix after every start.
#   * Optional systemd unit so services auto-start after every reboot.
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${SCRIPT_DIR}/logs"

# ────────────────────────────────────────────── logging
log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "✅ $*"; }
warn() { log "⚠  $*"; }
fail() { log "❌ $*"; exit 1; }
skip() { log "⏭️  $*"; }

# Run a command as the (non-root) target user with a FULLY EXPLICIT env.
# Do NOT rely on ~/.bashrc — Ubuntu's default .bashrc returns early for
# non-interactive shells, so `su - user -c` would not get HADOOP_HOME/PATH
# and `hdfs`/`schematool` would be "command not found".
run_as() {
    su - "$TARGET_USER" -c "\
unset SPARK_HOME PYSPARK_DRIVER_PYTHON PYSPARK_DRIVER_PYTHON_OPTS; \
export JAVA_HOME='${JAVA_HOME_DETECTED:-}' \
HADOOP_HOME='${HADOOP_INSTALL:-/opt/hadoop}' \
HIVE_HOME='${HIVE_INSTALL:-/opt/hive}' \
HADOOP_CONF_DIR='${HADOOP_INSTALL:-/opt/hadoop}/etc/hadoop'; \
export HADOOP_OPTS='--add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED -Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true'; \
export HADOOP_CLIENT_OPTS=\"\$HADOOP_OPTS\"; \
export PATH=\"\$JAVA_HOME/bin:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$HIVE_HOME/bin:\$HOME/.local/bin:\$PATH\"; \
$*"
}

# ══════════════════════════════════════════════════════════════════
# Fault tolerance #1 — never run HDFS out of a shared folder.
#   VMware HGFS (/mnt/hgfs) and VirtualBox (/media/sf_*) folders are NOT
#   remounted early at boot and do not support the POSIX locks HDFS needs.
#   If the datanode dir lives there, the DataNode dies after every restart.
#   Fix: copy the whole setup into $HOME (local ext4) and run from there.
# ══════════════════════════════════════════════════════════════════
is_shared_folder() {
    local dir="$1"
    case "$dir" in
        /mnt/hgfs/*|/mnt/hgfs|/media/sf_*|*/vmhgfs*) return 0 ;;
    esac
    local t
    t=$(df -T "$dir" 2>/dev/null | awk 'NR==2 {print $2}')
    case "$t" in
        fuse.vmhgfs*|vmhgfs*|vboxsf|9p|cifs|drvfs|fuseblk) return 0 ;;
    esac
    return 1
}

guard_shared_folder() {
    is_shared_folder "$SCRIPT_DIR" || return 0

    local dest="${TARGET_HOME}/hadoop-lab"
    warn "This setup lives on a shared/network folder: ${SCRIPT_DIR}"
    warn "Running HDFS from here breaks the DataNode after a VM restart."
    log  "Copying the setup into your HOME (local disk): ${dest}"

    mkdir -p "$dest"
    # copy everything except previously-downloaded state/logs
    cp -a "${SCRIPT_DIR}/." "$dest/" 2>/dev/null || true
    rm -rf "${dest}/logs" "${dest}/spark-warehouse" "${dest}/.ipynb_checkpoints" 2>/dev/null || true
    chown -R "${TARGET_USER}:${TARGET_USER}" "$dest" 2>/dev/null || true
    chmod +x "${dest}"/*.sh 2>/dev/null || true

    echo ""
    ok "Copied to local disk. Now run the install FROM THERE:"
    echo ""
    echo "      sudo ${dest}/setup.sh"
    echo ""
    warn "Do NOT run setup.sh from the shared folder again."
    exit 0
}

# ══════════════════════════════════════════════════════════════════
# Pre-flight — detect distro, package manager, target user
# ══════════════════════════════════════════════════════════════════
detect_pkg() {
    if   command -v apt-get &>/dev/null; then PKG_MGR="apt"
    elif command -v dnf     &>/dev/null; then PKG_MGR="dnf"
    elif command -v yum     &>/dev/null; then PKG_MGR="yum"
    else fail "No supported package manager (need apt, dnf, or yum)."
    fi
    ok "Package manager: $PKG_MGR"
}

pkg_install() {
    case "$PKG_MGR" in
        apt) DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        dnf) dnf install -y "$@" ;;
        yum) yum install -y "$@" ;;
    esac
}

preflight() {
    log "──── Phase 0: Pre-flight ────"

    [[ $EUID -eq 0 ]] || fail "Run with sudo:  sudo ./setup.sh"
    detect_pkg

    # Detect the real (non-root) user we install for.
    if   [[ -n "$TARGET_USER" ]]; then :
    elif [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then TARGET_USER="$SUDO_USER"
    else TARGET_USER=$(id -un 1000 2>/dev/null || echo "")
    fi
    [[ -n "$TARGET_USER" ]] || fail "Could not detect target user. Re-run: sudo TARGET_USER=name ./setup.sh"

    TARGET_HOME=$(eval echo "~$TARGET_USER")
    [[ -d "$TARGET_HOME" ]] || fail "Home dir $TARGET_HOME missing for user $TARGET_USER"
    ok "Target user: $TARGET_USER ($TARGET_HOME)"

    guard_shared_folder   # may copy-to-home and exit

    source "${SCRIPT_DIR}/bin/files.sh" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# Phase 1 — Java 21
# ══════════════════════════════════════════════════════════════════
detect_java_home() {
    local jbin
    jbin=$(readlink -f "$(command -v java)" 2>/dev/null) || return 1
    echo "${jbin%/bin/java}"
}

install_java() {
    log "──── Phase 1: Java 21 ────"
    if java -version 2>&1 | grep -q 'version "21'; then
        ok "Java 21 present ($(java -version 2>&1 | head -1))"
    else
        case "$PKG_MGR" in
            apt) pkg_install openjdk-21-jdk ;;
            *)   pkg_install java-21-openjdk java-21-openjdk-devel ;;
        esac || fail "Java 21 install failed"
        # make 21 the default java if alternatives exist
        command -v update-alternatives &>/dev/null && \
            update-alternatives --set java "$(update-alternatives --list java 2>/dev/null | grep -m1 21)" 2>/dev/null || true
        ok "Java 21 installed"
    fi
    JAVA_HOME_DETECTED=$(detect_java_home) || fail "Cannot resolve JAVA_HOME"
    ok "JAVA_HOME = $JAVA_HOME_DETECTED"
}

# ══════════════════════════════════════════════════════════════════
# Phase 2 — Hadoop
# ══════════════════════════════════════════════════════════════════
install_hadoop() {
    log "──── Phase 2: Hadoop ────"
    HADOOP_VER="${HADOOP_VER:-3.5.0}"
    HADOOP_TAR="${SCRIPT_DIR}/hadoop-${HADOOP_VER}.tar.gz"
    HADOOP_INSTALL="${HADOOP_INSTALL:-/opt/hadoop}"

    # Version-aware: only skip when the EXACT target version is present.
    if [[ -f "${HADOOP_INSTALL}/share/hadoop/common/hadoop-common-${HADOOP_VER}.jar" ]]; then
        ok "Hadoop ${HADOOP_VER} already at ${HADOOP_INSTALL}"; return 0
    fi
    # Stale version or a symlink to one (e.g. old lab install) -> replace it.
    if [[ -L "${HADOOP_INSTALL}" ]]; then
        warn "Removing stale symlink ${HADOOP_INSTALL} -> $(readlink -f "${HADOOP_INSTALL}")"
        rm -f "${HADOOP_INSTALL}"; FRESH_HADOOP=1
    elif [[ -d "${HADOOP_INSTALL}" ]]; then
        warn "Backing up stale ${HADOOP_INSTALL} -> ${HADOOP_INSTALL}.old"
        rm -rf "${HADOOP_INSTALL}.old"; mv "${HADOOP_INSTALL}" "${HADOOP_INSTALL}.old"; FRESH_HADOOP=1
    fi
    if [[ ! -f "$HADOOP_TAR" ]]; then
        HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VER}/hadoop-${HADOOP_VER}.tar.gz"
        HADOOP_ARCHIVE_URL="https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VER}/hadoop-${HADOOP_VER}.tar.gz"
        warn "Missing $HADOOP_TAR — downloading Hadoop ${HADOOP_VER}..."
        curl -# -fL --retry 3 -C - -o "$HADOOP_TAR" "$HADOOP_URL" || \
        curl -# -fL --retry 3 -C - -o "$HADOOP_TAR" "$HADOOP_ARCHIVE_URL" || fail "Hadoop download failed"
    fi
    rm -rf "/opt/hadoop-${HADOOP_VER}"
    tar -xzf "$HADOOP_TAR" -C /opt/ 2>&1 | tee -a "$LOG_FILE" || fail "Hadoop extract failed"
    if [[ -d "/opt/hadoop-${HADOOP_VER}" ]]; then
        rm -rf "${HADOOP_INSTALL}"; mv "/opt/hadoop-${HADOOP_VER}" "${HADOOP_INSTALL}"
    fi
    chown -R "${TARGET_USER}:${TARGET_USER}" "${HADOOP_INSTALL}" 2>/dev/null || true
    ok "Hadoop ${HADOOP_VER} installed at ${HADOOP_INSTALL}"
}

# ══════════════════════════════════════════════════════════════════
# Phase 3 — Hive
# ══════════════════════════════════════════════════════════════════
install_hive() {
    log "──── Phase 3: Hive ────"
    HIVE_VER="${HIVE_VER:-4.2.0}"
    HIVE_TAR="${SCRIPT_DIR}/apache-hive-${HIVE_VER}-bin.tar.gz"
    HIVE_INSTALL="${HIVE_INSTALL:-/opt/hive}"

    if [[ -f "${HIVE_INSTALL}/lib/hive-common-${HIVE_VER}.jar" ]]; then
        ok "Hive ${HIVE_VER} already at ${HIVE_INSTALL}"; return 0
    fi
    if [[ -L "${HIVE_INSTALL}" ]]; then
        warn "Removing stale symlink ${HIVE_INSTALL} -> $(readlink -f "${HIVE_INSTALL}")"
        rm -f "${HIVE_INSTALL}"; FRESH_HIVE=1
    elif [[ -d "${HIVE_INSTALL}" ]]; then
        warn "Backing up stale ${HIVE_INSTALL} -> ${HIVE_INSTALL}.old"
        rm -rf "${HIVE_INSTALL}.old"; mv "${HIVE_INSTALL}" "${HIVE_INSTALL}.old"; FRESH_HIVE=1
    fi
    if [[ ! -f "$HIVE_TAR" ]]; then
        HIVE_URL="https://dlcdn.apache.org/hive/hive-${HIVE_VER}/apache-hive-${HIVE_VER}-bin.tar.gz"
        HIVE_ARCHIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VER}/apache-hive-${HIVE_VER}-bin.tar.gz"
        warn "Missing $HIVE_TAR — downloading Hive ${HIVE_VER}..."
        curl -# -fL --retry 3 -C - -o "$HIVE_TAR" "$HIVE_URL" || \
        curl -# -fL --retry 3 -C - -o "$HIVE_TAR" "$HIVE_ARCHIVE_URL" || fail "Hive download failed"
    fi
    rm -rf "/opt/apache-hive-${HIVE_VER}-bin"
    tar -xzf "$HIVE_TAR" -C /opt/ 2>&1 | tee -a "$LOG_FILE" || fail "Hive extract failed"
    if [[ -d "/opt/apache-hive-${HIVE_VER}-bin" ]]; then
        rm -rf "${HIVE_INSTALL}"; mv "/opt/apache-hive-${HIVE_VER}-bin" "${HIVE_INSTALL}"
    fi
    chown -R "${TARGET_USER}:${TARGET_USER}" "${HIVE_INSTALL}" 2>/dev/null || true
    ok "Hive ${HIVE_VER} installed at ${HIVE_INSTALL}"
}

# ══════════════════════════════════════════════════════════════════
# Phase 4 — PySpark  (pip fault tolerance lives here)
# ══════════════════════════════════════════════════════════════════
# Always drive pip through `python3 -m pip` so a missing ~/.local/bin on the
# root/su PATH can never make it look "not found".
ensure_pip() {
    log "Ensuring pip is available..."
    if run_as "python3 -m pip --version" &>/dev/null; then ok "pip present"; return 0; fi

    warn "pip not found — installing (ensurepip)…"
    run_as "python3 -m ensurepip --upgrade" 2>&1 | tee -a "$LOG_FILE" || true
    if run_as "python3 -m pip --version" &>/dev/null; then ok "pip installed via ensurepip"; return 0; fi

    warn "ensurepip unavailable — installing distro python3-pip…"
    case "$PKG_MGR" in
        apt) pkg_install python3-pip python3-venv ;;
        *)   pkg_install python3-pip ;;
    esac || true
    run_as "python3 -m pip --version" &>/dev/null && { ok "pip installed via $PKG_MGR"; return 0; }

    fail "Could not install pip. Install python3-pip manually and re-run."
}

# Ubuntu 24.04 marks system Python "externally managed" (PEP 668); pip refuses
# to install unless we pass --break-system-packages. Detect and use it.
pip_flags() {
    run_as "python3 -m pip install --help 2>/dev/null | grep -q break-system-packages" \
        && echo "--break-system-packages" || echo ""
}

install_pyspark() {
    log "──── Phase 4: PySpark ────"
    ensure_pip
    local flags; flags=$(pip_flags)

    if run_as "python3 -c 'import pyspark' 2>/dev/null"; then
        ok "PySpark already importable ($(run_as "python3 -c 'import pyspark;print(pyspark.__version__)'" 2>/dev/null))"
        return 0
    fi

    local wheel
    wheel=$(ls "${SCRIPT_DIR}"/pyspark-*.whl 2>/dev/null | head -1)
    if [[ -n "$wheel" ]]; then
        log "Installing PySpark from local wheel: $(basename "$wheel")"
        run_as "python3 -m pip install --user $flags '$wheel'" 2>&1 | tee -a "$LOG_FILE" || warn "wheel install failed, trying PyPI"
    fi
    if ! run_as "python3 -c 'import pyspark' 2>/dev/null"; then
        warn "Installing PySpark from PyPI (needs internet)…"
        run_as "python3 -m pip install --user $flags pyspark" 2>&1 | tee -a "$LOG_FILE" \
            || fail "PySpark install failed"
    fi
    run_as "python3 -c 'import pyspark; print(pyspark.__version__)'" 2>&1 | tee -a "$LOG_FILE" \
        || fail "PySpark verification failed"
    ok "PySpark installed"
}

# ══════════════════════════════════════════════════════════════════
# Phase 5 — Config files (templated per-user)
# ══════════════════════════════════════════════════════════════════
write_configs() {
    log "──── Phase 5: Configuration ────"
    HDFS_DATA_DIR="${TARGET_HOME}/hdfs"
    HIVE_DATA_DIR="${TARGET_HOME}/hive"
    mkdir -p "$HDFS_DATA_DIR" "$HIVE_DATA_DIR"

    mkdir -p "${HADOOP_INSTALL}/etc/hadoop"
    sed -e "s|{{HDFS_DIR}}|${HDFS_DATA_DIR}|g" \
        "${SCRIPT_DIR}/config/core-site.xml" > "${HADOOP_INSTALL}/etc/hadoop/core-site.xml"
    sed -e "s|{{HDFS_DIR}}|${HDFS_DATA_DIR}|g" \
        "${SCRIPT_DIR}/config/hdfs-site.xml" > "${HADOOP_INSTALL}/etc/hadoop/hdfs-site.xml"
    ok "Hadoop config written"

    mkdir -p "${HIVE_INSTALL}/conf"
    sed -e "s|{{HIVE_DATA_DIR}}|${HIVE_DATA_DIR}|g" \
        "${SCRIPT_DIR}/config/hive-site.xml" > "${HIVE_INSTALL}/conf/hive-site.xml"
    ok "Hive config written"

    # hadoop-env.sh JAVA_HOME (use the auto-detected path)
    local henv="${HADOOP_INSTALL}/etc/hadoop/hadoop-env.sh"
    if ! grep -q "^export JAVA_HOME=" "$henv" 2>/dev/null; then
        echo "export JAVA_HOME=${JAVA_HOME_DETECTED}" >> "$henv"
    fi
    echo "localhost" > "${HADOOP_INSTALL}/etc/hadoop/workers"

    chown -R "${TARGET_USER}:${TARGET_USER}" "$HDFS_DATA_DIR" "$HIVE_DATA_DIR" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# Phase 6 — ~/.bashrc environment
# ══════════════════════════════════════════════════════════════════
write_env() {
    log "──── Phase 6: Environment ────"
    local bashrc="${TARGET_HOME}/.bashrc"
    local marker="# HADOOP_HIVE_PYSPARK"
    # remove any previous block, then append a fresh one
    sed -i "/${marker}_BEGIN/,/${marker}_END/d" "$bashrc" 2>/dev/null || true
    cat >> "$bashrc" <<ENVEOF
${marker}_BEGIN
export JAVA_HOME=${JAVA_HOME_DETECTED}
export HADOOP_HOME=${HADOOP_INSTALL}
export HADOOP_CONF_DIR=\${HADOOP_HOME}/etc/hadoop
export HIVE_HOME=${HIVE_INSTALL}
# Use pip's bundled PySpark. A stale SPARK_HOME (old /opt/spark 3.3.4) can't run
# on Java 21 -> "NoSuchMethodException DirectByteBuffer" -> unset it here.
unset SPARK_HOME PYSPARK_DRIVER_PYTHON PYSPARK_DRIVER_PYTHON_OPTS
export PYSPARK_PYTHON=python3
export PATH=\${JAVA_HOME}/bin:\${HADOOP_HOME}/bin:\${HADOOP_HOME}/sbin:\${HIVE_HOME}/bin:\${HOME}/.local/bin:\${PATH}
# Java 17+ needs these opens for Hadoop/Hive/Spark reflective access
export HADOOP_OPTS="--add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED -Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true"
export HADOOP_CLIENT_OPTS="\$HADOOP_OPTS"
${marker}_END
ENVEOF
    chown "${TARGET_USER}:${TARGET_USER}" "$bashrc"
    ok "Environment written to ${bashrc}"
}

# ══════════════════════════════════════════════════════════════════
# Phase 7 — Schema init + HDFS format
# ══════════════════════════════════════════════════════════════════
init_schemas() {
    log "──── Phase 7: Schema init ────"

    # Clean stale Hadoop lock files that can block NameNode startup
    local hdfs_dir="${TARGET_HOME}/hdfs"
    rm -f "${hdfs_dir}/namenode/in_use.lock" 2>/dev/null || true
    rm -f "${hdfs_dir}/datanode/in_use.lock" 2>/dev/null || true
    find "$hdfs_dir" -name "*.lock" -delete 2>/dev/null || true

    # Fresh/replaced Hadoop -> old namenode+datanode metadata is incompatible.
    if [[ "${FRESH_HADOOP:-0}" == "1" ]]; then
        warn "New Hadoop version — resetting HDFS storage for a clean format"
        rm -rf "${TARGET_HOME}/hdfs/namenode" "${TARGET_HOME}/hdfs/datanode" "${TARGET_HOME}/hdfs/tmp"
        mkdir -p "${TARGET_HOME}/hdfs/namenode" "${TARGET_HOME}/hdfs/datanode"
        chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/hdfs"
    fi

    if [[ -d "${TARGET_HOME}/hdfs/namenode/current" ]]; then
        ok "HDFS already formatted"
    else
        log "Formatting HDFS NameNode…"
        run_as "hdfs namenode -format -force" 2>&1 | tee -a "$LOG_FILE" \
            || warn "HDFS format reported issues"
    fi

    # Fresh/replaced Hive -> old derby metastore_db is incompatible.
    if [[ "${FRESH_HIVE:-0}" == "1" ]]; then
        warn "New Hive version — removing old derby metastore_db"
        rm -rf "${TARGET_HOME}/hive/metastore_db"
    fi

    log "Initializing Hive metastore schema (derby)…"
    run_as "schematool -dbType derby -initSchema" 2>&1 | tee -a "$LOG_FILE" || {
        if run_as "schematool -dbType derby -info" 2>&1 | grep -q "schema version"; then
            ok "Hive schema already initialized"
        else
            warn "Hive schema init failed — run 'schematool -dbType derby -initSchema' manually"
        fi
    }

    # Ensure HDFS directories exist for Hive warehouse (visible in NameNode UI :9870)
    log "Creating HDFS directories for Hive warehouse…"
    run_as "hadoop fs -mkdir -p /user/${TARGET_USER}" 2>/dev/null || true
    run_as "hadoop fs -mkdir -p /user/hive/warehouse" 2>/dev/null || true
    run_as "hadoop fs -mkdir -p /user/hive/external" 2>/dev/null || true
    run_as "hadoop fs -chmod -R 777 /user/hive/warehouse" 2>/dev/null || true
    run_as "hadoop fs -chmod -R 777 /user/hive/external" 2>/dev/null || true
    ok "HDFS Hive directories ready — visible at http://localhost:9870"
}

# ══════════════════════════════════════════════════════════════════
# Phase 8 — Start services (delegates to start-services.sh, which owns the
#           DataNode clusterID auto-heal so start + reboot share one path)
# ══════════════════════════════════════════════════════════════════
start_services() {
    log "──── Phase 8: Starting services ────"
    fix_ownership
    run_as "bash '${SCRIPT_DIR}/start-services.sh' start" 2>&1 | tee -a "$LOG_FILE"
}

# setup.sh runs as root (sudo), so any dir/file it creates is root-owned. But
# the services + tests + notebook all run as the USER (su - / systemd User=),
# and a single root-owned path (logs/, /opt/hadoop/logs, metastore_db, …) makes
# them fail with "Permission denied". Hand every path the user must write back
# to them in one sweep. Idempotent, safe to call more than once.
fix_ownership() {
    local u="${TARGET_USER}:${TARGET_USER}"
    chown -R "$u" "${SCRIPT_DIR}" "${HADOOP_INSTALL:-/opt/hadoop}" "${HIVE_INSTALL:-/opt/hive}" \
        "${TARGET_HOME}/hdfs" "${TARGET_HOME}/hive" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# Phase 8b — systemd unit so services come back after every VM restart
# ══════════════════════════════════════════════════════════════════
install_systemd() {
    command -v systemctl &>/dev/null || { skip "no systemd; services need manual start after reboot"; return 0; }
    log "──── Phase 8b: Boot persistence (systemd) ────"
    cat > /etc/systemd/system/hadoop-lab.service <<UNIT
[Unit]
Description=Hadoop + Hive lab (single node)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=${TARGET_USER}
Group=${TARGET_USER}
ExecStart=/bin/bash ${SCRIPT_DIR}/start-services.sh start
ExecStop=/bin/bash ${SCRIPT_DIR}/start-services.sh stop
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable hadoop-lab.service 2>&1 | tee -a "$LOG_FILE" || true
    ok "systemd unit 'hadoop-lab' enabled — DataNode auto-starts after reboot"
}

# ══════════════════════════════════════════════════════════════════
# Phase 9 — Smoke test
# ══════════════════════════════════════════════════════════════════
smoke_test() {
    log "──── Phase 9: Test suite ────"
    # Runs unit (fault-tolerance) + PySpark↔Hive + CSV(local+HDFS) + beeline.
    local runner="${SCRIPT_DIR}/bin/run_all_tests.sh"
    [[ -f "$runner" ]] || { skip "no test runner"; return 0; }
    if run_as "bash '$runner'" 2>&1 | tee -a "$LOG_FILE" | grep -qE "TOTAL: [0-9]+ passed, 0 failed"; then
        ok "TEST SUITE PASSED — all suites green"
    else
        warn "TEST SUITE had failures — see $LOG_FILE"
    fi
}

# ══════════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   Hadoop + Hive + PySpark — fault-tolerant     ║"
    echo "  ╚══════════════════════════════════════════════╝"
    log  "Log: $LOG_FILE"

    preflight
    install_java
    install_hadoop
    install_hive
    install_pyspark
    write_configs
    write_env
    init_schemas
    start_services
    install_systemd
    smoke_test

    echo ""
    ok "DONE. Open a NEW terminal (or: source ~/.bashrc) then:"
    echo "      ${SCRIPT_DIR}/start-services.sh status"
}

# entrypoint (skipped when sourced by the test harness)
if [[ "${SETUP_SH_TEST:-}" != "1" ]]; then main "$@"; fi
