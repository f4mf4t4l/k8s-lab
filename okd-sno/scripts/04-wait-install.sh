#!/usr/bin/env bash
# Wartet, bis die Installation abgeschlossen ist (nach dem Booten des ISOs).
source "$(dirname "$0")/common.sh"
need openshift-install

case "$INSTALL_METHOD" in
  agent)
    log "Warte auf Bootstrap ..."
    openshift-install agent wait-for bootstrap-complete --dir "$INSTALL_DIR" --log-level info
    log "Warte auf Installationsabschluss ..."
    openshift-install agent wait-for install-complete --dir "$INSTALL_DIR" --log-level info
    ;;
  bootstrap-in-place)
    log "Warte auf Bootstrap (inkl. Reboot des Knotens) ..."
    openshift-install wait-for bootstrap-complete --dir "$INSTALL_DIR" --log-level info
    log "Warte auf Installationsabschluss ..."
    openshift-install wait-for install-complete --dir "$INSTALL_DIR" --log-level info
    ;;
esac

log "Fertig! Zugriff:"
echo "  export KUBECONFIG=$INSTALL_DIR/auth/kubeconfig"
echo "  oc get nodes"
echo "  Console: https://console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "  User: kubeadmin / Passwort: $(cat "$INSTALL_DIR/auth/kubeadmin-password" 2>/dev/null || echo '?')"
