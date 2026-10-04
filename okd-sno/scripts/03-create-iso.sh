#!/usr/bin/env bash
# Erzeugt das bootfaehige ISO fuer den SNO-Knoten.
source "$(dirname "$0")/common.sh"
need openshift-install
[[ -f "$INSTALL_DIR/install-config.yaml" ]] || die "Zuerst scripts/02-render-configs.sh ausfuehren."

case "$INSTALL_METHOD" in
  agent)
    # Der Agent-Installer braucht nmstatectl fuer networkConfig
    need nmstatectl
    log "Erzeuge Agent-ISO ..."
    openshift-install agent create image --dir "$INSTALL_DIR" --log-level info
    ISO="$INSTALL_DIR/agent.x86_64.iso"
    ;;

  bootstrap-in-place)
    need curl
    log "Erzeuge Single-Node-Ignition ..."
    openshift-install create single-node-ignition-config --dir "$INSTALL_DIR"

    ISO_URL="$(openshift-install coreos print-stream-json \
      | grep -o '"location": *"[^"]*x86_64[^"]*live[^"]*\.iso"' \
      | head -1 | cut -d'"' -f4)"
    [[ -n "$ISO_URL" ]] || die "Konnte ISO-URL aus dem Stream nicht ermitteln."
    BASE_ISO="$WORK_DIR/$(basename "$ISO_URL")"
    if [[ ! -f "$BASE_ISO" ]]; then
      log "Lade CoreOS Live-ISO: $ISO_URL"
      curl -fL --retry 3 -o "$BASE_ISO" "$ISO_URL"
    fi

    ISO="$INSTALL_DIR/sno-live.iso"
    cp "$BASE_ISO" "$ISO"
    log "Bette Ignition ins ISO ein ..."
    if command -v coreos-installer >/dev/null 2>&1; then
      coreos-installer iso ignition embed -fi "$INSTALL_DIR/bootstrap-in-place-for-live-iso.ign" "$ISO"
    else
      need podman
      podman run --rm --privileged -v "$INSTALL_DIR:/data:Z" -w /data \
        quay.io/coreos/coreos-installer:release \
        iso ignition embed -fi bootstrap-in-place-for-live-iso.ign sno-live.iso
    fi
    ;;
esac

log "ISO fertig: $ISO"
log "Kubeconfig: $INSTALL_DIR/auth/kubeconfig"
log "kubeadmin-Passwort: $INSTALL_DIR/auth/kubeadmin-password"
