# EliteA Helm Chart

[![CI](https://github.com/EliteaAI/elitea_helm/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/EliteaAI/elitea_helm/actions/workflows/ci.yml)
[![Release](https://github.com/EliteaAI/elitea_helm/actions/workflows/release.yml/badge.svg)](https://github.com/EliteaAI/elitea_helm/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/EliteaAI/elitea_helm?label=chart)](https://github.com/EliteaAI/elitea_helm/releases/latest)
[![License](https://img.shields.io/github/license/EliteaAI/elitea_helm)](https://github.com/EliteaAI/elitea_helm/blob/main/LICENSE)

Helm chart for the EliteA AI platform (Pylon microservices) on Kubernetes (EKS, GKE, AKS, on-prem).

**Documentation for users of the chart (install, secrets, External Secrets, Argo CD, load balancers, SSO, CA):
[charts/README.md](charts/README.md).**

## Components

| Component | Template directory | Enabled by |
| --- | --- | --- |
| Pylon Main / Auth / Indexer | `charts/templates/pylon_{main,auth,indexer}/` | always |
| Pylon DeepWiki | `charts/templates/pylon_deepwiki/` | `pylon_deepwiki.enabled` |
| Pylon ImageGen | `charts/templates/pylon_imagegen/` | `pylon_imagegen.enabled` |
| Pylon Inventory | `charts/templates/pylon_inventory/` | `pylon_inventory.enabled` |
| PostgreSQL / Redis | `charts/templates/{postgresql,redis}/` | `embedded_services_pgsql` / `embedded_services_redis` |
| Load balancer (GCE / ALB / AGIC) | `charts/templates/ingress/` | `ingress_enabled` + `cloud_ingress_type` |
| Internal plugin repository | `charts/templates/internal_repo/` | `common.elitea_repo_type: internal` |
| OpenTelemetry Collector | `charts/templates/otel_collector/` | `otel_collector.enabled` |
| MCP Grafana / Azure DevOps | `charts/templates/mcp_{grafana,ado}/` | `mcp_grafana.enabled` / `mcp_ado.enabled` |

## Quick start

```bash
minikube start --cpus 6 --memory 16g --disk-size 60g
./examples/minikube/install.sh               # generates secrets, installs with small local values
kubectl -n elitea port-forward svc/pylon-main-svc 8080:8080     # http://localhost:8080
```

The default StorageClass is `premium-rwo` (GKE): override `*.storage.class` / `*.persistence.storageClass` elsewhere. Real secrets, StorageClasses and cloud load balancers are covered in [charts/README.md](charts/README.md).

## Examples (values + External Secrets per cloud)

| Cloud | Files |
|---|---|
| AWS (EKS, ALB, Secrets Manager) | [examples/aws/](examples/aws/) |
| GCP (GKE, GCE ingress, Secret Manager) | [examples/gcp/](examples/gcp/) |
| Azure (AKS, AGIC, Key Vault) | [examples/azure/](examples/azure/) |
| Local (minikube / kind) | [examples/minikube/](examples/minikube/): `./install.sh` creates secrets and installs |
| Local (MicroK8s) | [examples/microk8s/](examples/microk8s/): same as minikube with the `microk8s-hostpath` StorageClass |
| Secrets inside values (tests only) | [examples/inline-secrets/](examples/inline-secrets/) |
| Auto-generated secrets | [examples/autogen-secrets/](examples/autogen-secrets/): HMAC keys and DB passwords are generated, you pass only the 4 encryption keys |

Each folder has `values.yaml` (load balancer, TLS, StorageClasses, `existingSecret`) and `externalsecret.yaml`
(`SecretStore` + `ExternalSecret`). [examples/secret-keys.json](examples/secret-keys.json) lists every key the secret must contain.

```bash
kubectl create namespace elitea
kubectl apply -f examples/aws/externalsecret.yaml          # wait for STATUS SecretSynced
helm install elitea ./charts -n elitea -f examples/aws/values.yaml
```

Replace the placeholders (domain, certificate, project/vault/region names) first.

## Make targets

Targets take `NS` (namespace, default `test`), `VALS` (values file under `charts/`, default `values.yaml`),
`RELEASE` (default `elitea`) and `KUBE` (Kubernetes version for rendering).

```bash
make lint NS=elitea                         # helm lint --strict
make template NS=elitea VALS=prod.yaml      # render to build/render.yaml
make bump                                   # next version + CHANGELOG + tag
```

With the default `VALS`, `make lint` and `make template` add `charts/ci/test-values.yaml` (dummy secrets).
With your own `VALS` they validate exactly what you pass.

## Repository layout

- [`charts/Chart.yaml`](charts/Chart.yaml), [`charts/values.yaml`](charts/values.yaml), [`charts/values.schema.json`](charts/values.schema.json)
- [`charts/templates/`](charts/templates/) - Kubernetes manifests
- [`charts/data/configs/`](charts/data/configs/) - application-level Pylon config files
- [`charts/ci/`](charts/ci/) - values for lint/CI only (not packaged)
- [`Makefile`](Makefile) - operational commands; `build/` holds rendered output

## Configuration model

Two layers:

- Environment ConfigMaps from `charts/templates/<component>/config.yml`
  (`common.config` overridden by `pylon_X.config`)
- Pylon application configs in `charts/data/configs/<component>/`: `.yml` files are loaded as-is,
  `.yml.tpl` files go through Helm `tpl`.

Use Helm values for structural decisions (plugins, load order). Use `${ENV_VAR}` placeholders for secrets and
runtime values: they are resolved in the container from the pod environment, not at render time.

## Notes

- Queue names use `redis_queue_random_suffix` to avoid collisions when several installations share Redis.
- VPA objects are emitted only when the matching `resources.vpa_enabled` is true.
- Never commit real secrets. Use `common.existingSecret` (see charts/README.md).
