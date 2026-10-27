#!/usr/bin/env bash
# Uninstalls the release. The MySQL PVC is kept (helm.sh/resource-policy:
# keep), so data survives. Pass --purge to delete everything, data included.
#
# Usage:
#   ./scripts/teardown.sh dev
#   ./scripts/teardown.sh prod --purge
set -euo pipefail

ENV="${1:-}"
PURGE="${2:-}"

if [ "${ENV}" != "dev" ] && [ "${ENV}" != "prod" ]; then
  echo "Usage: $0 <dev|prod> [--purge]" >&2
  exit 1
fi

NAMESPACE="selfapp-${ENV}"

echo "[INFO] Uninstalling release 'selfapp' from namespace ${NAMESPACE}..."
helm uninstall selfapp -n "${NAMESPACE}" || echo "[WARN] Release not found, continuing"

if [ "${PURGE}" != "--purge" ]; then
  echo "[DONE] Release uninstalled. MySQL PVC and namespace kept."
  echo "[INFO] Re-run with --purge to delete them too."
  exit 0
fi

echo "[WARN] --purge: this deletes the namespace, the PVC and ALL MySQL data."
read -r -p "Type 'purge' to confirm: " CONFIRM
if [ "${CONFIRM}" != "purge" ]; then
  echo "Aborted. Release uninstalled, PVC and namespace kept."
  exit 0
fi

kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait

# Minikube's storage keeps files under /tmp/hostpath-provisioner/<namespace>/
# even after the PVC is deleted, and a new PVC with the same name would reuse
# them. Remove them so the next install really starts with an empty database.
if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
  minikube ssh -- sudo rm -rf "/tmp/hostpath-provisioner/${NAMESPACE}"
  echo "[INFO] Removed Minikube's leftover data for ${NAMESPACE}."
fi

echo "[DONE] Namespace ${NAMESPACE} and all its data removed."
