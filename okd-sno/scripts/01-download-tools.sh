#!/usr/bin/env bash
# Laedt openshift-install und oc (OKD/SCOS) nach $BIN_DIR.
source "$(dirname "$0")/common.sh"
need curl; need tar

if [[ -z "${OKD_VERSION}" ]]; then
  log "Ermittle neueste OKD-Version ..."
  OKD_VERSION="$(curl -fsSL https://api.github.com/repos/okd-project/okd/releases/latest \
    | grep -m1 '"tag_name"' | cut -d'"' -f4)"
  [[ -n "$OKD_VERSION" ]] || die "Konnte OKD-Version nicht ermitteln – bitte OKD_VERSION in env setzen."
fi
log "OKD-Version: ${OKD_VERSION}"

URL="https://github.com/okd-project/okd/releases/download/${OKD_VERSION}"
mkdir -p "$BIN_DIR" "$WORK_DIR"
cd "$WORK_DIR"

for pkg in openshift-install openshift-client; do
  f="${pkg}-linux-${OKD_VERSION}.tar.gz"
  if [[ ! -f "$f" ]]; then
    log "Lade $f ..."
    curl -fL --retry 3 -o "$f" "$URL/$f"
  fi
  tar -xzf "$f" -C "$BIN_DIR"
done
rm -f "$BIN_DIR/README.md"

echo "$OKD_VERSION" > "$WORK_DIR/okd-version"
log "Installiert:"
"$BIN_DIR/openshift-install" version
"$BIN_DIR/oc" version --client
