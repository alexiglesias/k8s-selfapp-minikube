# k8s-selfapp-minikube

Deploy selfapp-lite (from [docker-buildlab-selfapp](https://github.com/alexiglesias/docker-buildlab-selfapp)) on Kubernetes using Minikube — free, runs on your own machine. Covers Pods, Deployments, Services, Ingress, Secrets, and Helm, with zero cloud cost.

This is the Kubernetes-local project from the roadmap, adapted to deploy **selfapp-lite** (Nginx → Spring Boot → MySQL) instead of VProfile, since selfapp-lite is the simpler, already-built reference app.

## What this deploys

| Component | What it is |
|---|---|
| `mysql` | Single MySQL instance, backed by a PVC |
| `app` | The Spring Boot app from docker-buildlab-selfapp |
| `web` | Nginx, reverse-proxying to `app`, same role as `web/selfapp.conf` in the original repo |
| `memcached`, `rabbitmq` | Scaffolded, **disabled by default** — mirrors docker-buildlab-selfapp's own `docker-compose.yml`, where these services exist but the app doesn't connect to them yet |

Everything is packaged as a single Helm chart at `charts/selfapp/`, deployable to two namespaces (`selfapp-dev`, `selfapp-prod`) with different values files, or to any other Kubernetes cluster.

## What's confirmed vs. still assumed

This chart went through three rounds of corrections against real source files: `docker-compose.yml`, then `app/Dockerfile` + `pom.xml`, then finally `web/Dockerfile`. As of the third round, every assumption below has been checked against a real file — nothing left unverified.

**Round 1 (docker-compose.yml) — fixed real mistakes:** the app reads custom `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASS` env vars, not Spring's `spring.datasource.*` convention as I'd first guessed. The web image is `selfapp-lite-web`, not `selfapp-web`.

**Round 2 (app/Dockerfile + pom.xml) — assumptions confirmed correct:** `EXPOSE 8080` confirmed `app.containerPort`. `spring-boot-starter-actuator` in `pom.xml`, plus the Dockerfile's own `HEALTHCHECK` hitting `/actuator/health`, confirmed the probes could use a real health check rather than a plain TCP fallback. The Dockerfile's non-root `USER 1001` is now also pinned explicitly in `app-deployment.yaml`'s `securityContext`.

**Round 3 (web/Dockerfile) — found and fixed a real bug, not just a hypothetical one:** the real Dockerfile does `COPY selfapp.conf /etc/nginx/conf.d/default.conf` — it *replaces* the base nginx image's `default.conf` entirely. My chart originally mounted the config as a separate file (`/etc/nginx/conf.d/selfapp.conf`), which would have left both the base image's `default.conf` and my `selfapp.conf` present at once, two server blocks both listening on port 80. `web-deployment.yaml` now mounts the ConfigMap at `/etc/nginx/conf.d/default.conf` to replicate the real Dockerfile exactly. The probes were also switched to `httpGet` on `/`, matching the Dockerfile's own `wget --spider http://localhost/` healthcheck.

**Still true, not a chart bug:** `docker-compose.yml` has real-looking plaintext dev credentials (`rootpass`, `selfpass`) as defaults, which is normal for a local Compose file but worth being deliberate about — this chart's `values.yaml` uses `CHANGE_ME` placeholders instead of mirroring those, on purpose.

None of this was tested against a running cluster — no `helm`, `kubectl`, or `minikube` available in the environment I built this in, and no network path to install them. I validated every pure-YAML file with a YAML parser, checked brace-balance on all template files, and cross-checked every `include` call and every Deployment/Service selector-label pair by hand — but I could not run `helm template` or `helm lint`. Run those yourself as the first step, before `helm install`.

## Prerequisites

- Minikube
- kubectl
- Helm 3
- Docker (Minikube's driver, and for building images locally)
- Optionally, [Lens](https://k8slens.dev/) (free) to browse the cluster visually

## Secrets

`values.yaml` ships with placeholder MySQL credentials (`CHANGE_ME`). Never edit those in place and commit them. Instead, override at install time:

```bash
helm upgrade --install selfapp ./charts/selfapp \
  -n selfapp-dev \
  -f charts/selfapp/values.yaml \
  -f charts/selfapp/values-dev.yaml \
  --set mysql.rootPassword='something-strong' \
  --set mysql.password='something-else-strong'
```

Or create a gitignored `values-secrets.yaml` (already covered by `.gitignore`) and pass it as an extra `-f`.

## Usage

```bash
# 1. Bring up Minikube + ingress addon
./scripts/minikube-up.sh

# 2. Deploy to dev (builds images into Minikube's own Docker daemon)
./scripts/deploy.sh dev

# 3. Point selfapp.dev.local at Minikube and visit it
echo "$(minikube ip) selfapp.dev.local" | sudo tee -a /etc/hosts
open http://selfapp.dev.local   # or just curl it

# 4. Deploy to "prod" as well, side by side, in its own namespace
./scripts/deploy.sh prod

# 5. Explore the cluster
lens &   # or: kubectl get all -n selfapp-dev

# 6. Tear down when done
./scripts/teardown.sh dev
./scripts/teardown.sh prod --purge   # also deletes the PVC and namespace
```

## Manual equivalent (no wrapper scripts)

```bash
minikube start --memory=4096 --cpus=4
minikube addons enable ingress

kubectl create namespace selfapp-dev
kubectl create namespace selfapp-prod

helm lint ./charts/selfapp -f charts/selfapp/values.yaml -f charts/selfapp/values-dev.yaml

helm install selfapp ./charts/selfapp \
  -n selfapp-dev \
  -f charts/selfapp/values.yaml \
  -f charts/selfapp/values-dev.yaml
```

## Project structure

```
k8s-selfapp-minikube/
├── charts/
│   └── selfapp/
│       ├── Chart.yaml
│       ├── values.yaml            # shared defaults
│       ├── values-dev.yaml        # dev overrides
│       ├── values-prod.yaml       # "prod" overrides (still local Minikube)
│       └── templates/
│           ├── _helpers.tpl
│           ├── NOTES.txt
│           ├── mysql-secret.yaml
│           ├── mysql-pvc.yaml
│           ├── mysql-deployment.yaml
│           ├── mysql-service.yaml
│           ├── app-configmap.yaml
│           ├── app-deployment.yaml
│           ├── app-service.yaml
│           ├── web-configmap.yaml
│           ├── web-deployment.yaml
│           ├── web-service.yaml
│           ├── memcached-deployment.yaml   # disabled by default
│           ├── memcached-service.yaml      # disabled by default
│           ├── rabbitmq-deployment.yaml    # disabled by default
│           ├── rabbitmq-service.yaml       # disabled by default
│           └── ingress.yaml
└── scripts/
    ├── minikube-up.sh
    ├── deploy.sh
    └── teardown.sh
```

## Known gaps

- The `wait-for-mysql` init container does a blunt TCP poll (`nc -z`), not an actual "can I authenticate and query" check. Good enough for a lab, not a real readiness guarantee.
- No CI: correctness is checked with `helm lint` / `helm template` and manual review, not an automated pipeline.
- No resource-level NetworkPolicies — every component can currently talk to every other component inside the namespace, which is fine for a lab but not how you'd scope things in a real cluster.
- No Kubernetes Secret encryption at rest configured — Minikube's default etcd storage is unencrypted, same caveat as any local cluster.
- This is one Helm chart, not yet split into a library chart / subcharts pattern — fine at this size, would need restructuring if this grew into a larger multi-service system.

## What it replaces

This project's whole point is proving these Kubernetes/Helm concepts hold up without any cloud spend: AWS EKS costs roughly $0.10/hour (~€72/month for the control plane alone, before any worker nodes), and Kops-provisioned clusters incur their own EC2 costs. Minikube runs the same Kubernetes API surface, for free, on your own laptop.
