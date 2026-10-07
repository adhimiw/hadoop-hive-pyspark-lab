#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════
# copy-to-home.sh — copy this setup from a shared folder into the user's
# HOME (local disk), because HDFS breaks after a VM restart when its data
# dirs live on a VMware/VirtualBox shared folder.
#
# Run it (no sudo needed) then follow the printed instructions:
#     ./copy-to-home.sh
# ═══════════════════════════════════════════════════════════════════

SRC="$(cd "$(dirname "$0")" && pwd)"

# The user we copy for: the invoking (non-root) user even under sudo.
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo "~$USER_NAME")"
DEST="${USER_HOME}/hadoop-lab"

echo "Source : $SRC"
echo "Dest   : $DEST"

mkdir -p "$DEST"
# copy code + configs + tarballs; skip regenerable state
cp -a "$SRC/." "$DEST/"
rm -rf "$DEST/logs" "$DEST/spark-warehouse" "$DEST/.ipynb_checkpoints" "$DEST/metastore_db" "$DEST/derby.log" 2>/dev/null || true
chown -R "${USER_NAME}:${USER_NAME}" "$DEST" 2>/dev/null || true
chmod +x "$DEST"/*.sh 2>/dev/null || true

cat <<MSG

✅ Copied to local disk: $DEST

Now START THE SETUP FROM THERE (not from the shared folder):

    sudo ${DEST}/setup.sh

After it finishes, manage services with:

    ${DEST}/start-services.sh status
MSG
