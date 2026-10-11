# Validation record

Validated on 11 October 2026 against a four-node MicroK8s cluster. The previous
BNG and FRR releases and their data PVCs were removed before this clean install.

## Installation

The default repository values were used without a BNG override file.

| Release | Chart | Result |
|---|---|---|
| `osvbng` | `osvbng-0.11.0` | Deployed; 2/2 BNG pods ready |
| `osvbng-frr-isp` | `osvbng-frr-isp-0.3.0` | Deployed; 2/2 FRR pods ready |
| `osvbng-cpe-lab` | `osvbng-cpe-lab-0.1.4` | Deployed; BNG Blaster, UE API, CPE tools, GenieACS and MongoDB ready |

The clean install identified and fixed an HA template error that omitted the
`osvbng-members` ConfigMap for a valid two-member configuration. A second clean
installation completed successfully after the fix.

Static checks also passed:

- `helm lint` for `charts/bng`, `charts/frr-isp`, and `charts/cpe-lab`.
- `helm template` for all three charts.

## OSVBNG status

| Member | Node | HA state | Peer | BGP to FRR-A | BGP to FRR-B |
|---|---|---|---|---|---|
| `osvbng-0` (`bng-a`) | `ebpf-bng-node-02` | `ACTIVE` | Connected to `bng-b` | Established | Established |
| `osvbng-1` (`bng-b`) | `ebpf-bng-node-01` | `STANDBY` | Connected to `bng-a` | Established | Established |

OSVBNG reported 20 active IPoE/DHCPv4 subscriber sessions on the active member.
Its `residential` CGNAT pool reported 256 addresses, 20 allocated addresses,
20 subscribers, and 32,236 free port blocks. The active BNG advertised
`100.64.100.0/24`; both FRRs installed it through `172.31.255.2`.

## BNG Blaster status

The UE API reported:

```json
{"status":"ok","capacity":20,"socket":true,"netns":20}
```

BNG Blaster established all 20 configured sessions. Each session completed
DHCP Discover, Offer, Request, and ACK. The session API reported:

- `active_count`: 20
- session state: `Established`
- DHCP state: `Bound`
- outer VLAN: `100`
- inner VLANs: `100` through `119`
- UE addresses: `10.255.0.2` through `10.255.0.21` (allocation order is not guaranteed)
- Linux interfaces/namespaces: `bbl1`/`cpe1` through `bbl20`/`cpe20`

## Actual UE ping results

Two ICMP requests were sent from every UE namespace to the OSVBNG subscriber
gateway `10.255.0.1`.

| Session | Namespace | Loss | Average RTT |
|---:|---|---:|---:|
| 1 | `cpe1` | 0% | 0.822 ms |
| 2 | `cpe2` | 0% | 1.203 ms |
| 3 | `cpe3` | 0% | 1.380 ms |
| 4 | `cpe4` | 0% | 0.914 ms |
| 5 | `cpe5` | 0% | 1.476 ms |
| 6 | `cpe6` | 0% | 1.225 ms |
| 7 | `cpe7` | 0% | 1.039 ms |
| 8 | `cpe8` | 0% | 0.821 ms |
| 9 | `cpe9` | 0% | 1.012 ms |
| 10 | `cpe10` | 0% | 0.705 ms |
| 11 | `cpe11` | 0% | 1.233 ms |
| 12 | `cpe12` | 0% | 1.309 ms |
| 13 | `cpe13` | 0% | 0.972 ms |
| 14 | `cpe14` | 0% | 0.652 ms |
| 15 | `cpe15` | 0% | 1.150 ms |
| 16 | `cpe16` | 0% | 0.466 ms |
| 17 | `cpe17` | 0% | 0.601 ms |
| 18 | `cpe18` | 0% | 1.252 ms |
| 19 | `cpe19` | 0% | 1.161 ms |
| 20 | `cpe20` | 0% | 0.713 ms |

An additional three-packet sample from `cpe1` produced:

```text
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.430/0.544/0.750/0.145 ms
```

## Upstream Internet result

Both FRR routers reached the MikroTik gateway `192.168.88.1` with 0% loss:

- FRR-A: 3/3 replies, 2.996 ms average.
- FRR-B: 3/3 replies, 6.353 ms average.

The BNG-to-FRR BGP sessions were established, but the MikroTik reset both FRR
BGP connections after receiving their OPEN messages. Consequently, the FRRs
did not learn a default route and the BNGs retained a drop default. An actual
UE Internet test from `cpe1` therefore produced:

```text
PING 4.2.2.2 (4.2.2.2) 56(84) bytes of data.

--- 4.2.2.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss
```

The in-cluster subscriber path, HA peer connection, BNG-to-FRR routing, CGNAT
allocation, and all 20 UE namespaces are working. End-to-end Internet testing
must be repeated after the MikroTik BGP peers for `192.168.88.12` and
`192.168.88.13` accept ASN `65020`; the required configuration is in
[charts/frr-isp/MIKROTIK.md](charts/frr-isp/MIKROTIK.md).

Automatic subscriber-forwarding recovery after a hard BNG failure is still
being improved upstream and was not part of this validation.
