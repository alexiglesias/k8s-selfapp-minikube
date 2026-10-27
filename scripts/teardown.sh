#!/usr/bin/env bash
# Uninstalls the release. Does NOT delete the namespace or the MySQL PVC
# by default — pass --purge to remove everything, including data.
#
# Usage:
#   ./scripts/teardown.sh dev
#   ./scripts/teardown.sh prod
#   ./scripts/teardown.sh dev --purge
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

if [ "${PURGE}" = "--purge" ]; then
  echo "[WARN] --purge set: deleting the PVC (this destroys the MySQL data) and the namespace itself."
  read -r -p "Type 'purge' to confirm: " CONFIRM
  if [ "${CONFIRM}" = "purge" ]; then
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found
    echo "[DONE] Namespace ${NAMESPACE} and everything in it removed."
  else
    echo "Aborted purge. Release uninstalled, but namespace/PVC left in place."
  fi
else
  echo "[DONE] Release uninstalled. Namespace and PVC (if any) left in place."
  echo "[INFO] Re-run with --purge to remove those too."
fi
