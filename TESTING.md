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

After the MikroTik peers were updated to `192.168.88.12` and `.13`, both eBGP
sessions reached `ESTABLISHED`. Each FRR learned and installed `0.0.0.0/0`
through `192.168.88.1`, and both BNGs installed resolved ECMP default paths
through `172.31.255.4` and `172.31.255.5`.

Three ICMP requests were then sent from every UE namespace to Internet address
`4.2.2.2`:

| Session | Namespace | Loss | Average RTT |
|---:|---|---:|---:|
| 1 | `cpe1` | 0% | 8.473 ms |
| 2 | `cpe2` | 0% | 7.831 ms |
| 3 | `cpe3` | 0% | 14.573 ms |
| 4 | `cpe4` | 0% | 11.576 ms |
| 5 | `cpe5` | 0% | 7.261 ms |
| 6 | `cpe6` | 0% | 9.208 ms |
| 7 | `cpe7` | 0% | 10.881 ms |
| 8 | `cpe8` | 0% | 7.250 ms |
| 9 | `cpe9` | 0% | 8.038 ms |
| 10 | `cpe10` | 0% | 7.374 ms |
| 11 | `cpe11` | 0% | 8.055 ms |
| 12 | `cpe12` | 0% | 12.654 ms |
| 13 | `cpe13` | 0% | 7.077 ms |
| 14 | `cpe14` | 0% | 16.966 ms |
| 15 | `cpe15` | 0% | 7.595 ms |
| 16 | `cpe16` | 0% | 7.088 ms |
| 17 | `cpe17` | 0% | 9.032 ms |
| 18 | `cpe18` | 0% | 10.544 ms |
| 19 | `cpe19` | 0% | 8.090 ms |
| 20 | `cpe20` | 0% | 8.420 ms |

Result: 60/60 Internet ICMP replies, 0% loss across all 20 sessions. The
subscriber path, CGNAT, BNG-to-FRR ECMP, FRR-to-MikroTik BGP, and upstream NAT
all passed end to end.

Automatic subscriber-forwarding recovery after a hard BNG failure is still
being improved upstream and was not part of this validation.

## Upstream HA fix validation — 24 October 2026

The BNG image was rebuilt from upstream commit `753e934` and pinned by digest
as `ghcr.io/infinitydon/osvbng:main-753e934`. The two-member StatefulSet was
rolled to this image and tested with 20 IPoE sessions.

Graceful switchover passed in both directions:

| Direction | New active | Restored sessions | CGNAT mappings | GARPs | Proxmox FDB | UE Internet pings |
|---|---|---:|---:|---:|---|---:|
| BNG-A to BNG-B | `osvbng-1` | 20 | 20 | 20 | `tap167i8` to `tap166i8` | 20/20 |
| BNG-B to BNG-A | `osvbng-0` | 20 | 20 | 20 | `tap166i8` to `tap167i8` | 20/20 |

Both directions retained BGP reachability through the two FRRs. The reverse
promotion specifically logged `Starting GARP flood` and sent all 20 GARPs,
confirming the merged switch-back fix.

A separate hard-stop test removed the active member while leaving its peer.
The peer reached `STANDBY_ALONE` but did not autonomously promote to `ACTIVE`,
including when the remaining member had `preempt: true`. The deployment was
restored to two healthy members (`ACTIVE`/`STANDBY`) with 20 sessions and 20/20
Internet pings. Automatic hard-failure promotion therefore remains upstream
work; the merged fix validates graceful bidirectional switchover only.
