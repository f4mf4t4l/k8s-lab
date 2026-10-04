# Template – wird von scripts/02-render-configs.sh mit envsubst befuellt.
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
metadata:
  name: ${CLUSTER_NAME}
compute:
  - name: worker
    replicas: 0              # SNO: keine separaten Worker
controlPlane:
  name: master
  replicas: 1                # SNO: genau ein Control-Plane-Knoten
networking:
  networkType: OVNKubernetes
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  serviceNetwork:
    - 172.30.0.0/16
  machineNetwork:
    - cidr: ${MACHINE_NETWORK}
platform:
  none: {}
${BOOTSTRAP_IN_PLACE_BLOCK}
# OKD braucht kein Red-Hat-Pull-Secret – ein Dummy-Eintrag genuegt.
pullSecret: '{"auths":{"fake":{"auth":"aWQ6cGFzcwo="}}}'
sshKey: '${SSH_PUBKEY}'
