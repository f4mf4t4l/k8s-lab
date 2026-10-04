# OKD Single Node (SNO) – Installationsanleitung

Diese Anleitung installiert einen **OKD-Cluster auf einem einzelnen Knoten**
(Single Node OpenShift/OKD, „SNO“) – auf Bare Metal oder als KVM/libvirt-VM.
Alle benötigten Dateien liegen in diesem Verzeichnis.

```
okd-sno/
├── env.example                     # zentrale Variablen (→ env kopieren)
├── config/
│   ├── install-config.yaml.tpl     # Cluster-Definition
│   └── agent-config.yaml.tpl       # Knoten/Netzwerk (Agent-based Installer)
├── dns/
│   ├── dnsmasq-okd-sno.conf        # DNS mit dnsmasq
│   ├── bind-zone.db.example        # DNS mit BIND
│   └── hosts.example               # /etc/hosts für den Admin-PC
├── scripts/
│   ├── 01-download-tools.sh        # openshift-install + oc laden
│   ├── 02-render-configs.sh        # Templates → install-Verzeichnis
│   ├── 03-create-iso.sh            # bootfähiges ISO erzeugen
│   ├── 04-wait-install.sh          # Installation überwachen
│   └── 05-post-install.sh          # htpasswd-User, Image-Registry
├── manifests/                      # YAMLs für die Nacharbeiten
└── libvirt/
    ├── create-vm.sh                # Test-VM anlegen und ISO booten
    └── dnsmasq-libvirt-network.xml # libvirt-Netz inkl. SNO-DNS
```

---

## 1. Überblick

Bei SNO laufen Control Plane und Workloads auf **einem** Knoten. Einen
Bootstrap-Knoten oder Load Balancer braucht man nicht: API und Ingress zeigen
direkt auf die IP des Knotens.

Zwei Installationsmethoden werden unterstützt (Auswahl über `INSTALL_METHOD` in `env`):

| Methode | Vorteile | Wann nutzen |
|---|---|---|
| **`agent`** (Agent-based Installer, **empfohlen**) | statische IP im ISO, Validierungen vor der Installation, ein einziges ISO | Standardfall, Bare Metal ohne DHCP |
| **`bootstrap-in-place`** | klassische SNO-Methode, kein `nmstatectl` nötig | DHCP mit fester Reservierung vorhanden |

Ablauf (beide Methoden):

```
Admin-PC: Tools laden → Configs erzeugen → ISO bauen
                                             │
Knoten:                       ISO booten ◄───┘
                              → installiert sich auf die Disk → Reboot(s)
Admin-PC: wait-for install-complete → oc login
```

## 2. Voraussetzungen

### 2.1 Hardware des SNO-Knotens

| Ressource | Minimum | Empfehlung (Lab) |
|---|---|---|
| vCPU | 8 | 8–16 |
| RAM | 16 GB | 32 GB |
| Disk | 120 GB | 150 GB+ (SSD/NVMe!) |
| Netzwerk | 1 NIC, Internetzugang | |

> Langsame Disks (HDD) führen oft zu etcd-Timeouts – SSD/NVMe verwenden.
> Bei einer VM: `cpu host-passthrough` setzen (macht `libvirt/create-vm.sh` automatisch).

### 2.2 Admin-PC (Linux, x86_64)

- `curl`, `tar`, `envsubst` (Paket `gettext`)
- `nmstatectl` (Paket `nmstate`) – **nur bei `INSTALL_METHOD=agent`**
- `podman` **oder** `coreos-installer` – **nur bei `bootstrap-in-place`**
- `htpasswd` (Paket `httpd-tools` / `apache2-utils`) – für Post-Install
- optional für die VM: `libvirt`, `virt-install`, `qemu-kvm`
- SSH-Schlüssel: `ssh-keygen -t ed25519`

Fedora / RHEL / CentOS Stream:

```bash
sudo dnf install -y curl tar gettext nmstate podman httpd-tools \
                    libvirt virt-install qemu-kvm
```

Debian / Ubuntu:

```bash
sudo apt install -y curl tar gettext-base nmstate podman apache2-utils \
                    libvirt-daemon-system virtinst qemu-kvm
```

### 2.3 DNS (Pflicht!)

Folgende Einträge müssen **vom Knoten und vom Admin-PC** auflösbar sein
(Beispiel: Cluster `sno`, Domain `lab.local`, IP `192.168.122.10`):

| Name | Typ | Ziel |
|---|---|---|
| `api.sno.lab.local` | A | 192.168.122.10 |
| `api-int.sno.lab.local` | A | 192.168.122.10 |
| `*.apps.sno.lab.local` | A (Wildcard) | 192.168.122.10 |
| `sno.sno.lab.local` | A + PTR | 192.168.122.10 |

Fertige Konfigurationen:

- **dnsmasq:** `dns/dnsmasq-okd-sno.conf` → `/etc/dnsmasq.d/` und `systemctl restart dnsmasq`
- **BIND:** `dns/bind-zone.db.example`
- **libvirt-Lab:** `libvirt/dnsmasq-libvirt-network.xml` (das libvirt-Netz liefert DNS gleich mit)

Test:

```bash
dig +short api.sno.lab.local
dig +short test.apps.sno.lab.local     # muss ebenfalls die Knoten-IP liefern
dig +short -x 192.168.122.10
```

## 3. Konfiguration

```bash
cd okd-sno
cp env.example env
vi env
```

Wichtige Werte in `env`:

| Variable | Bedeutung |
|---|---|
| `OKD_VERSION` | leer = neuestes Release von [okd-project/okd](https://github.com/okd-project/okd/releases) |
| `INSTALL_METHOD` | `agent` oder `bootstrap-in-place` |
| `CLUSTER_NAME`, `BASE_DOMAIN` | ergibt `api.<CLUSTER_NAME>.<BASE_DOMAIN>` |
| `NODE_IP`, `NODE_PREFIX`, `NODE_GATEWAY`, `NODE_DNS` | Netz des Knotens |
| `NODE_INTERFACE`, `NODE_MAC` | NIC-Name und MAC des Knotens |
| `MACHINE_NETWORK` | Subnetz des Knotens (CIDR) |
| `INSTALL_DISK` | Ziel-Disk, z. B. `/dev/vda`, `/dev/nvme0n1` |
| `SSH_PUBKEY_FILE` | wird als `core`-User-Key hinterlegt |

> **Bare Metal:** NIC-Name und MAC findet man z. B. durch Booten einer
> Live-Distribution (`ip -br link`). Für die Disk ist `/dev/disk/by-id/...`
> robuster als `/dev/sdX`.

> **Pull Secret:** OKD benötigt kein Red-Hat-Pull-Secret. Das Template enthält
> den üblichen Dummy `{"auths":{"fake":{"auth":"aWQ6cGFzcwo="}}}`. Wer einen
> eigenen Registry-Mirror nutzt, trägt hier dessen Credentials ein.

## 4. Installation

### Schritt 1 – Tools herunterladen

```bash
./scripts/01-download-tools.sh
```

Lädt `openshift-install` und `oc` der gewählten OKD-Version nach `./bin/`.

> Optional ins PATH aufnehmen: `export PATH=$PWD/bin:$PATH`

### Schritt 2 – Konfiguration erzeugen

```bash
./scripts/02-render-configs.sh
cat work/install/install-config.yaml
cat work/install/agent-config.yaml     # nur bei agent
```

> `openshift-install` **löscht** die YAMLs beim ISO-Bau. Eine Kopie liegt in
> `work/config-backup/`. Für einen neuen Versuch Schritt 2 einfach wiederholen.

### Schritt 3 – ISO erzeugen

```bash
./scripts/03-create-iso.sh
```

Ergebnis:

- `agent` → `work/install/agent.x86_64.iso`
- `bootstrap-in-place` → `work/install/sno-live.iso` (CoreOS-Live-ISO mit eingebetteter Ignition)

Außerdem entstehen `work/install/auth/kubeconfig` und
`work/install/auth/kubeadmin-password` – **gut aufbewahren!**

> Die Ignition-Zertifikate sind **24 Stunden** gültig. Das ISO also zeitnah
> booten, sonst Schritte 2–3 wiederholen.

### Schritt 4 – Knoten booten

**Bare Metal:** ISO auf einen USB-Stick schreiben und davon booten (oder per BMC/iDRAC/iLO virtuell mounten):

```bash
sudo dd if=work/install/agent.x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Bootreihenfolge: **Disk vor USB/CD**. Beim ersten Start ist die Disk leer, also
bootet das ISO; nach der Installation bootet der Knoten automatisch von der Disk.

**libvirt-VM (Lab):**

```bash
# einmalig: libvirt-Netz mit DNS + fester DHCP-Adresse
sudo virsh net-destroy default; sudo virsh net-undefine default
sudo virsh net-define libvirt/dnsmasq-libvirt-network.xml
sudo virsh net-start default && sudo virsh net-autostart default

./libvirt/create-vm.sh            # 8 vCPU, 32 GB RAM, 150 GB Disk
```

Größen lassen sich überschreiben: `VM_RAM_MB=24576 VM_DISK_GB=120 ./libvirt/create-vm.sh`

### Schritt 5 – Installation abwarten

```bash
./scripts/04-wait-install.sh
```

Dauer: ca. **40–90 Minuten** (je nach Internet und Disk). Der Knoten startet
dabei mehrmals neu – das ist normal.

Fortschritt auf dem Knoten verfolgen:

```bash
ssh core@192.168.122.10
journalctl -f                                       # allgemein
sudo journalctl -u assisted-service -f              # agent: Validierungen
sudo journalctl -b -f -u bootkube.service           # bootstrap-in-place
```

### Schritt 6 – Zugriff

```bash
export KUBECONFIG=$PWD/work/install/auth/kubeconfig
oc get nodes
oc get clusterversion
oc get co            # alle ClusterOperators: AVAILABLE=True, DEGRADED=False
```

Web-Konsole: `https://console-openshift-console.apps.sno.lab.local`
Login: `kubeadmin` / Inhalt von `work/install/auth/kubeadmin-password`

## 5. Nacharbeiten (empfohlen)

```bash
./scripts/05-post-install.sh admin 'SicheresPasswort!'
```

Das Skript

1. legt einen **htpasswd-Identity-Provider** mit User `admin` (cluster-admin) an
   (`manifests/oauth-htpasswd.yaml`),
2. aktiviert die **interne Image-Registry** mit `emptyDir`
   (`manifests/image-registry-emptydir-patch.yaml`).

Nach erfolgreichem Login als `admin` den `kubeadmin` entfernen:

```bash
oc login -u admin https://api.sno.lab.local:6443
oc delete secret kubeadmin -n kube-system
```

### Persistenter Storage

SNO hat out-of-the-box **keine StorageClass**. Optionen für das Lab:

- **LVM Storage (LVMS)** – nutzt eine zweite Disk im Knoten (über OperatorHub)
- **local-path-provisioner** von Rancher – einfach, nutzt Pfad auf der Root-Disk
- **NFS-Subdir-Provisioner** – wenn ein NFS-Server vorhanden ist

Danach kann die Registry auf PVC umgestellt werden: `manifests/image-registry-pvc.yaml`.

## 6. Troubleshooting

| Problem | Ursache / Lösung |
|---|---|
| `nmstatectl: command not found` beim ISO-Bau | Paket `nmstate` installieren (nur `agent`) |
| Agent-Validierung „DNS“ / „NTP“ schlägt fehl | DNS-Einträge (Abschnitt 2.3) bzw. NTP-Erreichbarkeit prüfen: `sudo journalctl -u assisted-service` |
| Knoten bootet nach Installation wieder das ISO | Bootreihenfolge: Disk vor CD/USB, oder ISO nach erstem Reboot auswerfen |
| `x509: certificate has expired` | ISO älter als 24 h → Schritte 2–3 neu ausführen |
| etcd-Timeouts, API instabil | Disk zu langsam → SSD/NVMe; `fio`-Test: fsync-Latenz < 10 ms (p99) |
| ClusterOperator `ingress`/`console` degraded | `*.apps`-Wildcard-DNS fehlt oder falsch |
| `wait-for` bricht mit Timeout ab | Einfach erneut ausführen – die Installation läuft auf dem Knoten weiter |
| Pending CSRs nach Neustart (Cluster > 24 h aus) | `oc get csr -o name \| xargs oc adm certificate approve` |

Logs einsammeln:

```bash
# agent
./bin/openshift-install agent gather bootstrap --dir work/install
# bootstrap-in-place
./bin/openshift-install gather bootstrap --dir work/install --bootstrap 192.168.122.10 --master 192.168.122.10
# laufender Cluster
oc adm must-gather
```

## 7. Cluster entfernen / neu installieren

```bash
# libvirt-VM
sudo virsh destroy okd-sno; sudo virsh undefine okd-sno --remove-all-storage

# Bare Metal: Disk vor Neuinstallation löschen (von einem Live-System)
sudo wipefs -a /dev/nvme0n1

# lokale Installationsdaten
rm -rf work/install work/config-backup
```

## 8. Hinweise

- **Upgrades:** `oc adm upgrade` bzw. in der Konsole unter *Administration → Cluster Settings*.
  Bei SNO kommt es während Upgrades zu kurzen API-Ausfällen – normal, da es keine Redundanz gibt.
- **Herunterfahren:** `sudo shutdown -h now` auf dem Knoten. Nach längerer Pause
  ggf. ausstehende CSRs genehmigen (siehe Troubleshooting).
- **Offizielle Doku:** <https://docs.okd.io> → *Installing → Installing on a single node*
  bzw. *Installing an on-premise cluster with the Agent-based Installer*.
