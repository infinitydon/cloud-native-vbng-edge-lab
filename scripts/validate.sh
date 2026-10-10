#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-osvbng-edge}"

kubectl wait --namespace "$namespace" --for=condition=Ready pod \
  --selector app=osvbng --timeout=5m
kubectl wait --namespace "$namespace" --for=condition=Ready pod \
  --selector app.kubernetes.io/name=osvbng-frr-isp --timeout=5m
kubectl wait --namespace "$namespace" --for=condition=Ready pod \
  --selector app=osvbng-cpe-lab --timeout=5m

echo "BNG pods"
kubectl get pods --namespace "$namespace" --selector app=osvbng -o wide

echo "HA status"
for pod in osvbng-0 osvbng-1; do
  kubectl exec --namespace "$namespace" "$pod" -- python3 -c \
    "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/api/show/ha/status').read().decode())"
done

echo "BNG BGP status"
for pod in osvbng-0 osvbng-1; do
  kubectl exec --namespace "$namespace" "$pod" -- \
    ip netns exec dataplane vtysh -c 'show bgp ipv4 unicast summary'
done

cpe_pod="$(kubectl get pods --namespace "$namespace" --selector app=osvbng-cpe-lab \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"

echo "Subscriber sessions"
kubectl exec --namespace "$namespace" "$cpe_pod" -c ue-api -- \
  curl -fsS http://127.0.0.1:8081/sessions

echo "UE 1 internet test"
kubectl exec --namespace "$namespace" "$cpe_pod" -c ue-api -- sh -c \
  "printf '%s' '{\"destination\":\"4.2.2.2\",\"count\":3}' | curl -fsS -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8081/sessions/1/ping"

echo "Active CGNAT pool"
active_pod="$(for pod in osvbng-0 osvbng-1; do
  state="$(kubectl exec --namespace "$namespace" "$pod" -- python3 -c \
    "import urllib.request,json; print(json.load(urllib.request.urlopen('http://127.0.0.1:8080/api/show/ha/status'))['data']['srgs'][0]['state'])")"
  if [ "$state" = ACTIVE ]; then echo "$pod"; break; fi
done)"
kubectl exec --namespace "$namespace" "$active_pod" -- python3 -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/api/show/cgnat/pools').read().decode())"
