# FRR ISP router

See [`../DEPLOYMENT.md`](../DEPLOYMENT.md) for the complete ordered platform
installation. This file is the FRR-specific reference.

See [MIKROTIK.md](MIKROTIK.md) for the RouterOS 7.23.1 upstream BGP,
firewall, NAT, validation, and removal commands.

See [NODE-NETPLAN.md](NODE-NETPLAN.md) for the persistent node parent-link
configuration required by the Multus macvlan attachments.

This optional chart proves that the CGNAT pool does not need to share the
OSVBNG core subnet. It provides an FRR 10.7.0 ISP edge with VirtIO-backed
Multus macvlan interfaces.

The default HA profile uses eBGP ECMP rather than VRRP:

- FRR member core addresses: `172.31.255.4` and `.5`
- FRR member upstream addresses: `192.168.88.12` and `.13`
- routed lab CGNAT pool: `100.64.100.0/24`

The default routing profile uses eBGP:

- OSVBNG ASN: `65010`
- ISP FRR ASN: `65020`
- MikroTik ASN: `65030`
- every BNG peers with both ISP routers
- both ISP routers peer with the MikroTik at `192.168.88.1`
- the MikroTik advertises only the default route to the ISP routers
- the ISP routers advertise only the routed CGNAT prefix to the MikroTik
- only the BNG whose SRG is active originates the subscriber and CGNAT
  prefixes
- both ISP routers retain the learned route independently
- each BNG imports only `0.0.0.0/0` and installs both FRR next hops in VPP

Both FRR pods use required node affinity for
`osvbng.infinitydon.com/bng-frr-ha=true` and required hostname anti-affinity.
This is the same eligible worker pool used by the BNG StatefulSet. Both core
and upstream macvlan attachments use the single `enp8s19` parent; there is no
`nodeName` pinning.

There are no VRRP VIPs. MikroTik installs ECMP paths through `.12` and `.13`,
and each BNG installs ECMP defaults through `172.31.255.4` and `.5`.
The FRR macvlan interfaces use stable explicit MAC addresses so BGP can
re-establish immediately after a pod replacement. Proxy ARP is disabled; it
must remain disabled because core and uplink VirtIO interfaces share one L2.

OSVBNG 0.16 natively associates the prefixes under
`ha.srgs.default.networks` with SRG state. It originates those prefixes while
the SRG is `ACTIVE` or `ACTIVE_SOLO` and withdraws them in standby states.
The ISP routers do not query the Kubernetes or OSVBNG APIs.

The BNG profile applies `OSVBNG-IMPORT-DEFAULT` to accept only the default
route and `OSVBNG-EXPORT` to its eBGP neighbors. Production deployments should
also narrow the export policy to the exact subscriber and CGNAT allocations.
The integration profile sets `osvbng.bgp.advertiseSubscriberPrefix: false`,
so FRR learns only the routed CGNAT pool. Set it to `true` only when the private
subscriber pool must be reachable as a non-NAT routed service.

When `bgp.enabled` is `false`, the chart installs a static fallback route for
`cgnat.prefix` through `cgnat.staticNextHop`. Set the next hop to the core
address of the BNG that should receive traffic in non-BGP mode. This fallback
does not provide automatic BNG failover.

The BNG chart's main `values.yaml` already contains the matching transit,
CGNAT, and BGP settings.

Automatic recovery of subscriber forwarding after a hard BNG failure is still
being improved upstream. Validate it with the selected OSVBNG release and the
target switching environment before production use.

```shell
helm upgrade --install osvbng ./helm-chart/bng \
  --namespace osvbng-ha --create-namespace --wait

helm upgrade --install osvbng-frr-isp ./helm-chart/frr-isp \
  --namespace osvbng-ha --create-namespace --wait

kubectl get pods -n osvbng-ha -l app.kubernetes.io/name=osvbng-frr-isp -o wide
kubectl exec -n osvbng-ha deploy/osvbng-frr-isp-a -c frr -- ip address
kubectl exec -n osvbng-ha deploy/osvbng-frr-isp-a -c frr -- \
  vtysh -c "show bgp ipv4 unicast summary" \
        -c "show bgp ipv4 unicast 100.64.100.0/24" \
        -c "show ip route 100.64.100.0/24"

kubectl exec -n osvbng-ha osvbng-0 -c osvbng -- \
  vtysh -c "show bgp ipv4 unicast summary"
```
