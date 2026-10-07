#!/usr/bin/env bash
# Unit tests for the fault-tolerance logic — no real Hadoop needed.
# Mocks hdfs/pkill/sleep and feeds fake logs. Run:  bash bin/test_faults.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
check() { # check <desc> <expected> <actual>
    if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1))
    else echo "  FAIL: $1 (want '$2' got '$3')"; FAIL=$((FAIL+1)); fi
}

echo "== is_shared_folder (setup.sh) =="
SETUP_SH_TEST=1 source "${ROOT}/setup.sh" >/dev/null 2>&1
is_shared_folder "/mnt/hgfs/setup"        ; check "VMware /mnt/hgfs -> shared"   0 $?
is_shared_folder "/media/sf_share/setup"  ; check "VBox /media/sf_ -> shared"    0 $?
is_shared_folder "/home/u/hadoop-lab"     ; check "home path -> NOT shared"      1 $?

echo "== heal_datanode (start-services.sh) =="
START_SVC_TEST=1 source "${ROOT}/start-services.sh" >/dev/null 2>&1
# neutralize real side-effect commands
hdfs()  { :; }
pkill() { :; }
sleep() { :; }

# scenario 1: stale clusterID -> must wipe datanode dir and return 0
TMP=$(mktemp -d)
export HADOOP_HOME="$TMP"; mkdir -p "$TMP/logs"
printf 'blah\njava.io.IOException: Incompatible clusterIDs in /home/u/hdfs/datanode\n' \
    > "$TMP/logs/hadoop-u-datanode-host.log"
DN_DATA_DIR="$TMP/dn"; mkdir -p "$DN_DATA_DIR/current"; touch "$DN_DATA_DIR/stale.file"
heal_datanode; rc=$?
check "clusterID mismatch -> returns heal(0)" 0 "$rc"
[[ -e "$DN_DATA_DIR/stale.file" ]] && left=yes || left=no
check "clusterID mismatch -> datanode dir wiped" "no" "$left"
[[ -d "$DN_DATA_DIR" ]] && kept=yes || kept=no
check "clusterID mismatch -> dir itself preserved" "yes" "$kept"
rm -rf "$TMP"

# scenario 2: healthy log -> no-op, return 1
TMP=$(mktemp -d)
export HADOOP_HOME="$TMP"; mkdir -p "$TMP/logs"
printf 'INFO all good, datanode registered\n' > "$TMP/logs/hadoop-u-datanode-host.log"
DN_DATA_DIR="$TMP/dn"; mkdir -p "$DN_DATA_DIR"; touch "$DN_DATA_DIR/keep.file"
heal_datanode; rc=$?
check "healthy log -> returns no-heal(1)" 1 "$rc"
[[ -e "$DN_DATA_DIR/keep.file" ]] && left=yes || left=no
check "healthy log -> datanode dir untouched" "yes" "$left"
rm -rf "$TMP"

# scenario 3: lock error -> heal
TMP=$(mktemp -d)
export HADOOP_HOME="$TMP"; mkdir -p "$TMP/logs"
printf 'Cannot lock storage /home/u/hdfs/datanode. The directory is already locked\n' \
    > "$TMP/logs/hadoop-u-datanode-host.log"
DN_DATA_DIR="$TMP/dn"; mkdir -p "$DN_DATA_DIR"; touch "$DN_DATA_DIR/x"
heal_datanode; rc=$?
check "lock error -> returns heal(0)" 0 "$rc"
rm -rf "$TMP"

echo "== pip fault-tolerance assumptions =="
# core claim: 'python3 -m pip' works even if the 'pip' binary isn't on PATH
python3 -m pip --version >/dev/null 2>&1 && r=ok || r=no
check "python3 -m pip resolves module" "ok" "$r"
# PEP668 detection: does this python need --break-system-packages?
if python3 -m pip install --help 2>/dev/null | grep -q break-system-packages; then f="--break-system-packages"; else f=""; fi
echo "  INFO: pip_flags on this host = '${f:-<none>}'"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
