#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-osvbng-edge}"

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install osvbng charts/bng \
  --namespace "$namespace" \
  --values charts/frr-isp/bng-values.yaml \
  --wait --timeout 15m

helm upgrade --install osvbng-frr charts/frr-isp \
  --namespace "$namespace" \
  --wait --timeout 10m

helm upgrade --install osvbng-cpe-lab charts/cpe-lab \
  --namespace "$namespace" \
  --set genieacs.enabled=false \
  --wait --timeout 10m
