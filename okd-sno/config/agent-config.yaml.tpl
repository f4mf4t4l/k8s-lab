# Template – wird von scripts/02-render-configs.sh mit envsubst befuellt.
# Nur fuer INSTALL_METHOD=agent relevant.
apiVersion: v1beta1
kind: AgentConfig
metadata:
  name: ${CLUSTER_NAME}
rendezvousIP: ${NODE_IP}
hosts:
  - hostname: ${NODE_HOSTNAME}
    role: master
    interfaces:
      - name: ${NODE_INTERFACE}
        macAddress: ${NODE_MAC}
    rootDeviceHints:
      deviceName: ${INSTALL_DISK}
    networkConfig:            # NMState-Syntax
      interfaces:
        - name: ${NODE_INTERFACE}
          type: ethernet
          state: up
          mac-address: ${NODE_MAC}
          ipv4:
            enabled: true
            dhcp: false
            address:
              - ip: ${NODE_IP}
                prefix-length: ${NODE_PREFIX}
          ipv6:
            enabled: false
      dns-resolver:
        config:
          server:
            - ${NODE_DNS}
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: ${NODE_GATEWAY}
            next-hop-interface: ${NODE_INTERFACE}
            table-id: 254
