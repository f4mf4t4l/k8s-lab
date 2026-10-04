#!/usr/bin/env bash
# Legt eine libvirt/KVM-VM fuer den SNO-Test an und bootet das ISO.
# Voraussetzung: libvirt, virt-install, Netzwerk "default" (192.168.122.0/24).
source "$(dirname "$0")/../scripts/common.sh"
need virt-install

VM_NAME="${VM_NAME:-okd-sno}"
VM_CPUS="${VM_CPUS:-8}"
VM_RAM_MB="${VM_RAM_MB:-32768}"
VM_DISK_GB="${VM_DISK_GB:-150}"
LIBVIRT_NET="${LIBVIRT_NET:-default}"

case "$INSTALL_METHOD" in
  agent)              ISO="$INSTALL_DIR/agent.x86_64.iso" ;;
  bootstrap-in-place) ISO="$INSTALL_DIR/sno-live.iso" ;;
esac
[[ -f "$ISO" ]] || die "ISO nicht gefunden: $ISO – zuerst scripts/03-create-iso.sh"

# ISO dorthin kopieren, wo qemu lesen darf
sudo cp "$ISO" /var/lib/libvirt/images/${VM_NAME}.iso

log "Erzeuge VM $VM_NAME ($VM_CPUS vCPU, ${VM_RAM_MB} MB RAM, ${VM_DISK_GB} GB Disk)"
sudo virt-install \
  --name "$VM_NAME" \
  --vcpus "$VM_CPUS" \
  --memory "$VM_RAM_MB" \
  --cpu host-passthrough \
  --os-variant centos-stream9 \
  --disk "size=${VM_DISK_GB},bus=virtio,format=qcow2" \
  --cdrom "/var/lib/libvirt/images/${VM_NAME}.iso" \
  --network "network=${LIBVIRT_NET},model=virtio,mac=${NODE_MAC}" \
  --boot hd,cdrom \
  --graphics vnc \
  --noautoconsole

log "VM gestartet. Konsole: sudo virsh console $VM_NAME  bzw. virt-manager"
