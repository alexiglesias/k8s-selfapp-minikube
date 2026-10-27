#!/usr/bin/env bash
# Deploys selfapp to Minikube, into either the dev or prod namespace.
#
# Usage:
#   ./scripts/deploy.sh dev
#   ./scripts/deploy.sh prod
set -euo pipefail

ENV="${1:-}"

if [ "${ENV}" != "dev" ] && [ "${ENV}" != "prod" ]; then
  echo "Usage: $0 <dev|prod>" >&2
  exit 1
fi

NAMESPACE="selfapp-${ENV}"
cd "$(dirname "$0")/.."

echo "[INFO] Ensuring namespace ${NAMESPACE} exists..."
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

if [ "${ENV}" = "dev" ]; then
  echo "[INFO] Building images into Minikube's own Docker daemon..."
  echo "[INFO] (requires the app/web source at ../docker-buildlab-selfapp relative to this repo)"
  minikube image build -t selfapp-lite:dev ../docker-buildlab-selfapp/app
  minikube image build -t selfapp-lite-web:dev ../docker-buildlab-selfapp/web
fi

echo "[INFO] Linting the chart..."
helm lint ./charts/selfapp -f "./charts/selfapp/values.yaml" -f "./charts/selfapp/values-${ENV}.yaml"

echo "[INFO] Deploying to namespace ${NAMESPACE}..."
helm upgrade --install selfapp ./charts/selfapp \
  -n "${NAMESPACE}" \
  -f "./charts/selfapp/values.yaml" \
  -f "./charts/selfapp/values-${ENV}.yaml" \
  --wait --timeout 5m

echo "[DONE]"
kubectl get pods -n "${NAMESPACE}"
