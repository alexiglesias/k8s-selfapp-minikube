#!/usr/bin/env bash
# Starts Minikube with enough resources for the full stack (MySQL is the
# heaviest piece) and enables the Ingress addon.
set -euo pipefail

if ! command -v minikube >/dev/null 2>&1; then
  echo "[ERROR] minikube is not installed. See https://minikube.sigs.k8s.io/docs/start/" >&2
  exit 1
fi

echo "[INFO] Starting Minikube (4GB RAM, 4 CPUs)..."
minikube start --memory=4096 --cpus=4

echo "[INFO] Enabling the ingress addon..."
minikube addons enable ingress

echo "[INFO] Waiting for the ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "[DONE] Minikube is up. minikube ip: $(minikube ip)"
