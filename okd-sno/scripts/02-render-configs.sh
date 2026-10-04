#!/usr/bin/env bash
# Erzeugt install-config.yaml (und agent-config.yaml) aus den Templates.
source "$(dirname "$0")/common.sh"
need envsubst

[[ -f "$SSH_PUBKEY_FILE" ]] || die "SSH Public Key nicht gefunden: $SSH_PUBKEY_FILE (ssh-keygen -t ed25519)"
export SSH_PUBKEY; SSH_PUBKEY="$(cat "$SSH_PUBKEY_FILE")"

case "$INSTALL_METHOD" in
  agent)
    export BOOTSTRAP_IN_PLACE_BLOCK="" ;;
  bootstrap-in-place)
    export BOOTSTRAP_IN_PLACE_BLOCK="bootstrapInPlace:
  installationDisk: ${INSTALL_DISK}" ;;
  *) die "Unbekannte INSTALL_METHOD: $INSTALL_METHOD" ;;
esac

export CLUSTER_NAME BASE_DOMAIN NODE_HOSTNAME NODE_IP NODE_PREFIX NODE_GATEWAY \
       NODE_DNS NODE_INTERFACE NODE_MAC MACHINE_NETWORK INSTALL_DISK

# openshift-install verbraucht (loescht) die Configs – daher frisches Verzeichnis
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

envsubst < config/install-config.yaml.tpl > "$INSTALL_DIR/install-config.yaml"
if [[ "$INSTALL_METHOD" == "agent" ]]; then
  envsubst < config/agent-config.yaml.tpl > "$INSTALL_DIR/agent-config.yaml"
fi

# Sicherungskopie, weil openshift-install die Dateien beim Erzeugen entfernt
mkdir -p "$WORK_DIR/config-backup"
cp "$INSTALL_DIR"/*.yaml "$WORK_DIR/config-backup/"

log "Configs erzeugt in $INSTALL_DIR:"
ls -1 "$INSTALL_DIR"
