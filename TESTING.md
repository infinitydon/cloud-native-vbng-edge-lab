# Validation record

Validated on 10 October 2026 against a four-node MicroK8s cluster.

## Static validation

- `helm lint` passed for `charts/bng`, `charts/frr-isp`, and `charts/cpe-lab`.
- `helm template` passed for all three charts.
- The repository contains no remaining `192.168.88.250` or `192.168.88.251` defaults.

## Live FRR validation

The FRR chart was installed in `osvbng-ha` alongside the existing two-member BNG StatefulSet.

| Check | Result |
|---|---|
| FRR-A scheduled with uplink `192.168.88.12/24` | Pass |
| FRR-B scheduled with uplink `192.168.88.13/24` | Pass |
| Both FRRs reached MikroTik `192.168.88.1` | Pass, 0% loss |
| FRR-A established BGP with both BNG members | Pass |
| FRR-B established BGP with both BNG members | Pass |
| Both FRRs learned `100.64.100.0/24` from active BNG-A | Pass |
| MikroTik eBGP to `.12` and `.13` | Pending router peer update |

The final subscriber-to-internet test must be run after the MikroTik neighbors are changed from the previous `.250/.251` addresses to `.12/.13`. The required RouterOS commands are in [charts/frr-isp/MIKROTIK.md](charts/frr-isp/MIKROTIK.md).
