#!/usr/bin/env bash
# Typische Nacharbeiten fuer einen Lab-SNO:
#   - htpasswd-Login mit Admin-User
#   - interne Image-Registry aktivieren (emptyDir, nicht persistent!)
# Aufruf: scripts/05-post-install.sh <admin-user> <passwort>
source "$(dirname "$0")/common.sh"
need oc; need htpasswd
export KUBECONFIG="$INSTALL_DIR/auth/kubeconfig"

ADMIN_USER="${1:-admin}"
ADMIN_PASS="${2:-}"
[[ -n "$ADMIN_PASS" ]] || die "Aufruf: $0 <admin-user> <passwort>"

log "Lege htpasswd-Secret an ..."
htpasswd -c -B -b "$WORK_DIR/htpasswd" "$ADMIN_USER" "$ADMIN_PASS"
oc create secret generic htpass-secret -n openshift-config \
  --from-file=htpasswd="$WORK_DIR/htpasswd" --dry-run=client -o yaml | oc apply -f -
oc apply -f manifests/oauth-htpasswd.yaml
oc adm policy add-cluster-role-to-user cluster-admin "$ADMIN_USER"

log "Aktiviere interne Image-Registry (emptyDir) ..."
oc patch configs.imageregistry.operator.openshift.io cluster --type merge \
  --patch-file manifests/image-registry-emptydir-patch.yaml

log "Fertig. Nach erfolgreichem Login als '$ADMIN_USER' kann kubeadmin entfernt werden:"
echo "  oc delete secret kubeadmin -n kube-system"
