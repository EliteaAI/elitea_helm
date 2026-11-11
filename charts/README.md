# elitea

Helm chart for the EliteA AI platform (Pylon microservices) on Kubernetes (EKS, GKE, AKS, on-prem).

Contents: [Quick start](#quick-start) · [Production install](#production-install) · [Secrets](#secrets) ·
[External Secrets Operator](#external-secrets-operator) · [Argo CD](#argo-cd) · [Load balancer](#load-balancer) ·
[External PostgreSQL / Redis](#external-postgresql--redis) · [External CA](#external-ca) · [SSO](#sso) ·
[Optional components](#optional-components) · [Upgrade / uninstall](#upgrade--uninstall) · [Troubleshooting](#troubleshooting)

## Requirements

- Kubernetes 1.27+, Helm 3.12+, `kubectl`
- A default or named StorageClass (the defaults use `premium-rwo`, a GKE class: override it on other clouds)
- For `aws` / `azure` load balancers: AWS Load Balancer Controller / Application Gateway Ingress Controller

## Quick start

A throw-away install on a local cluster (kind, minikube, Docker Desktop) with embedded PostgreSQL and Redis,
no ingress. Secrets are generated on the spot.

```bash
rand() { openssl rand 60 | base64 | tr '/+' '_-'; }

helm install elitea oci://ghcr.io/eliteaai/charts/elitea --version <version> \
  -n elitea --create-namespace \
  --set common.secrets.auth.application_auth_secret_key="$(rand)" \
  --set common.secrets.auth.default_admin_password="$(rand)" \
  --set common.secrets.main.application_main_secret_key="$(rand)" \
  --set common.secrets.main.secrets_master_key="$(openssl rand 32 | openssl base64 -A | tr '+/' '-_')" \
  --set pylon_auth.storage.class=standard \
  --set pylon_main.storage.class=standard \
  --set pylon_indexer.storage.class=standard \
  --set postgresql.persistence.storageClass=standard \
  --set redis.persistence.storageClass=standard \
  --set postgresql.persistence.size=10Gi

kubectl -n elitea get pods -w
kubectl -n elitea port-forward svc/pylon-main-svc 8080:8080     # http://localhost:8080
```

Use `kubectl get sc` to find your StorageClass name (`standard` on kind and minikube).
Log in with the admin password you generated (keep it: it is not shown again).
HMAC keys and database passwords are auto-generated and stay stable on upgrade.

## Production install

1. Pick the cloud and domain, put everything in a values file (no secrets in it, see [Secrets](#secrets)):

   ```yaml
   # prod-values.yaml
   ingress_enabled: true
   cloud_ingress_type: aws            # gcp | aws | azure

   common:
     existingSecret: elitea-secrets   # created in the next step
     config:
       app_proto: https
       app_host: elitea.example.com
       cookies_secure: "true"

   ingress:
     annotations:                     # example for AWS: TLS certificate
       alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
       alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
       alb.ingress.kubernetes.io/ssl-redirect: "443"

   pylon_main:
     storage: {class: gp3, size: 50Gi, tmp_size: 20Gi}
   pylon_auth:
     storage: {class: gp3, size: 1Gi}
   pylon_indexer:
     storage: {class: gp3, size: 20Gi}
   ```

2. Create the namespace and the Secret (or use [External Secrets](#external-secrets-operator)):

   ```bash
   kubectl create namespace elitea
   rand() { openssl rand 40 | base64 | tr '/+' '_-'; }
   kubectl -n elitea create secret generic elitea-secrets \
     --from-literal=postgres_user=elitea  --from-literal=postgres_password="$(rand)" \
     --from-literal=redis_password="$(rand)" \
     --from-literal=rpc_hmac_key="$(rand)"      --from-literal=event_hmac_key="$(rand)" \
     --from-literal=exposure_hmac_key="$(rand)" --from-literal=indexer_hmac_key="$(rand)" \
     --from-literal=mesh_hmac_key="$(rand)" \
     --from-literal=application_auth_secret_key="$(rand)" \
     --from-literal=default_admin_password="$(rand)" \
     --from-literal=application_main_secret_key="$(rand)" \
     --from-literal=secrets_master_key="$(openssl rand 32 | openssl base64 -A | tr '+/' '-_')"
   ```

3. Install and point DNS at the load balancer:

   ```bash
   helm install elitea oci://ghcr.io/eliteaai/charts/elitea --version <version> -n elitea -f prod-values.yaml
   kubectl -n elitea get ingress
   ```

Ready-made per-cloud files (values + External Secrets): `examples/aws`, `examples/gcp`, `examples/azure` in the repository.

## Secrets

Four ways to provide credentials, from simplest to most production-ready:

| Mode | How | Use for |
|---|---|---|
| Generated | Leave `postgres_password`, `redis_password`, `common.secrets.hmacs.*`, `application_auth_secret_key`, `application_main_secret_key` and `secrets_master_key` empty (`common.secrets.hmac_auto_generate: true`) | Quick start, dev. Needs cluster access (`lookup`), so not for `helm template` / Argo CD |
| Values | Set `common.secrets.*` in a values file | Tests. Values end up in the Helm release Secret and usually in git |
| External Secret (chart-managed) | `common.externalSecret.enabled: true` | Production on AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |
| Existing Secret | `common.existingSecret: <name>` | **Only** for secrets that do not come from `externalSecret` (Sealed Secrets, Vault Agent, SOPS, `kubectl create secret`) |

Rules:

- `common.secrets.auth.*` and `common.secrets.main.*` encrypt data and **must never change after the first install**. Empty keys are generated once (with `hmac_auto_generate: true`) and reused on `helm upgrade`. `default_admin_password` is never generated: set it.
- Keys that must never change (`common.secrets.hmacs.*`, `auth.application_auth_secret_key`, `main.application_main_secret_key`, `main.secrets_master_key`): on `helm upgrade` the value already stored in the cluster always wins over `values.yaml`. To rotate one, delete the Secret first. Needs `lookup`, so not for `helm template` / Argo CD.
- With `existingSecret` or `externalSecret` the chart creates no secrets (MCP ones included) and ignores `common.secrets`.
  The Secret must exist before the install and contain these keys:

  | Key | Notes |
  |---|---|
  | `postgres_user`, `postgres_password` | required, also used by embedded PostgreSQL |
  | `redis_password` | required, may be empty only if Redis has no password |
  | `rpc_hmac_key`, `event_hmac_key`, `exposure_hmac_key`, `indexer_hmac_key`, `mesh_hmac_key` | required, `openssl rand 64 \| base64 -w0 \| tr '/+' '_-'` |
  | `application_auth_secret_key`, `default_admin_password` | required |
  | `application_main_secret_key`, `secrets_master_key` | required, `secrets_master_key` is a Fernet key |
  | `grafana_service_account_token` | only when `mcp_grafana.enabled` |
  | `personal_access_token`, `mcp_api_key`, `mcp_api_keys` (JSON string) | only when `mcp_ado.enabled` (`mcp_api_key` with the legacy key, `mcp_api_keys` with multiple keys) |
  | `authorization_endpoint`, `client_id`, `client_secret`, `end_session_endpoint`, `metadata_endpoint`, `token_endpoint`, `url_mode`, `userinfo_endpoint`, `sso_token_expiration` | only for `sso_provider: oidc` |

- Missing keys are not detected at render time: the pod fails with `CreateContainerConfigError`.

## External Secrets Operator

Install [External Secrets Operator](https://external-secrets.io) once per cluster, then let it create the
Secret from your cloud secret manager. Store all values as one JSON secret, for example `elitea/prod`:

```json
{"postgres_user":"elitea","postgres_password":"...","redis_password":"...",
 "rpc_hmac_key":"...","event_hmac_key":"...","exposure_hmac_key":"...","indexer_hmac_key":"...","mesh_hmac_key":"...",
 "application_auth_secret_key":"...","default_admin_password":"...",
 "application_main_secret_key":"...","secrets_master_key":"..."}
```

Create a `SecretStore` for your cloud (pick one):

```yaml
# AWS Secrets Manager (IRSA: the service account has secretsmanager:GetSecretValue)
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata: {name: elitea-store, namespace: elitea}
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
      auth:
        jwt:
          serviceAccountRef: {name: external-secrets-sa}
---
# GCP Secret Manager (Workload Identity)
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata: {name: elitea-store, namespace: elitea}
spec:
  provider:
    gcpsm:
      projectID: my-project
      auth:
        workloadIdentity:
          clusterLocation: europe-west1
          clusterName: my-cluster
          serviceAccountRef: {name: external-secrets-sa}
---
# Azure Key Vault (Workload Identity)
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata: {name: elitea-store, namespace: elitea}
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: https://my-vault.vault.azure.net
      serviceAccountRef: {name: external-secrets-sa}
```

### ExternalSecret created by the chart (AWS / GCP / Azure)

Store all keys as one JSON secret (see `examples/secret-keys.json`). With `enabled: true` the chart creates both the
`SecretStore` (in the release namespace) and the `ExternalSecret`. You only need External Secrets Operator in the
cluster and a service account (`serviceAccount`) bound to the cloud identity (Workload Identity / IRSA).
To use an existing (Cluster)SecretStore instead, set `createStore: false` and `storeName` / `storeKind`:

```yaml
common:
  externalSecret:
    enabled: true
    name: elitea-secrets        # Secret the operator creates, used by all pods
    key: elitea/prod            # JSON secret name in the cloud secret manager (Azure: letters, digits, dashes only, e.g. elitea-prod)
    provider: gcp               # gcp | aws | azure
    gcp: {projectID: my-project, clusterLocation: europe-west1, clusterName: my-cluster}
    # aws: {region: eu-central-1}
    # azure: {vaultUrl: "https://my-vault.vault.azure.net"}
    # serviceAccount: external-secrets-sa
    # createStore: false        # use your own store instead:
    # storeName: my-store
    # storeKind: ClusterSecretStore
```

### Your own ExternalSecret (advanced, with `existingSecret`)

Only if you must map keys one by one (for example one Key Vault secret per key, see `examples/azure`).
Create the `ExternalSecret` that produces the Secret named in `common.existingSecret`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: {name: elitea-secrets, namespace: elitea}
spec:
  refreshInterval: 1h
  secretStoreRef: {name: elitea-store, kind: SecretStore}
  target:
    name: elitea-secrets          # = common.existingSecret
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: elitea/prod          # JSON secret above: every field becomes a key
```

```bash
kubectl apply -f secretstore.yaml -f externalsecret.yaml
kubectl -n elitea get externalsecret elitea-secrets     # STATUS must be SecretSynced
helm install elitea ... -n elitea -f prod-values.yaml   # with common.existingSecret: elitea-secrets
```

Old ESO versions (before 0.16) use `apiVersion: external-secrets.io/v1beta1`. Always wait for `SecretSynced`
before installing, and never rotate the `auth` / `main` keys through the store.
Rotating the PostgreSQL password in the store does not change the password inside the embedded database.

## Argo CD

Argo renders with `helm template`, which has no `lookup`, so nothing can be auto-generated: use
`existingSecret` (for example with External Secrets, sync wave earlier than the app).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: elitea, namespace: argocd}
spec:
  project: default
  source:
    repoURL: ghcr.io/eliteaai/charts      # OCI; for an HTTP repo use the repo URL and `chart:`
    chart: elitea
    targetRevision: <version>
    helm:
      valuesObject:
        ingress_enabled: true
        cloud_ingress_type: gcp
        common:
          existingSecret: elitea-secrets
          config: {app_proto: https, app_host: elitea.example.com, cookies_secure: "true"}
  destination: {server: https://kubernetes.default.svc, namespace: elitea}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
```

## Load balancer

`ingress_enabled: true` plus `cloud_ingress_type`:

| Value | Ingress class | Needs in cluster | Session affinity |
|---|---|---|---|
| `gcp` | `gce` | nothing on GKE | `BackendConfig` (created by the chart) |
| `aws` | `alb` | AWS Load Balancer Controller | target group stickiness annotation |
| `azure` | `azure-application-gateway` | Application Gateway Ingress Controller | cookie affinity annotation |

Affinity cookie lifetime: `ingress.sticky.cookieTtlSeconds` (default 86400). TLS is not configured by default;
add it through `ingress.annotations`:

```yaml
# GKE: managed certificate + static IP
ingress:
  annotations:
    networking.gke.io/managed-certificates: elitea-cert
    kubernetes.io/ingress.global-static-ip-name: elitea-ip
# AKS: certificate from Key Vault / ssl redirect
ingress:
  annotations:
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: elitea-cert
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
```

Without a load balancer (`ingress_enabled: false`) expose `svc/pylon-main-svc:8080` yourself (own Ingress,
Gateway API, `kubectl port-forward`).

## External PostgreSQL / Redis

```yaml
embedded_services_pgsql: false
embedded_services_redis: false
redis_aws_cloud: true                  # ElastiCache with TLS
common:
  existingSecret: elitea-secrets       # postgres_user/postgres_password/redis_password inside
  config:
    postgres_host: mydb.cluster-xyz.eu-central-1.rds.amazonaws.com
    postgres_port: "5432"
    postgres_db: eliteadb              # must exist before the install
    redis_host: my-redis.xyz.cache.amazonaws.com
    redis_port: "6379"
    redis_ssl: "true"
```

Without `existingSecret`, `common.secrets.postgres_password` is required for an external database.

## External CA

For a corporate proxy or private CAs. Create the ConfigMap before installing:

```bash
kubectl -n elitea create configmap my-cas --from-file=corp-root-ca.crt --from-file=corp-issuing-ca.crt
```

```yaml
external_ca_enabled: true
external_ca_configmap: my-cas
external_ca_files: [corp-root-ca.crt, corp-issuing-ca.crt]   # file names inside the ConfigMap
```

The ConfigMap is mounted at `/cacerts` in every service. With a proxy also set `external_proxy_enabled: true`,
`http_proxy`, `https_proxy`, `no_proxy`.

## SSO

Default is the built-in form login. OIDC and SAML:

```yaml
# OIDC: endpoints, client_id and client_secret are keys of the Secret (existingSecret or common.secrets)
common:
  config:
    sso_provider: oidc
```

```yaml
# SAML
common:
  config:
    sso_provider: saml
    authn_destination: https://idp.example.com/sso
    logout_destination: https://idp.example.com/slo
    saml_issuer: https://idp.example.com/saml/metadata
saml_existing_secret: saml
# saml_idp_use_metadata: true     # use key idp_metadata instead of idp_cert
```

The SAML Secret holds `sp_key`, `sp_cert` and `idp_cert` (or `idp_metadata`) as single-line PEMs
with literal `\n`:

```bash
pem() { awk 'NF{printf "%s\\n",$0}' "$1"; }
kubectl -n elitea create secret generic saml \
  --from-literal=sp_key="$(pem sp.key)" --from-literal=sp_cert="$(pem sp.crt)" \
  --from-literal=idp_cert="$(pem idp.crt)"
```

## Optional components

```yaml
pylon_imagegen:  {enabled: true}     # image generation
pylon_deepwiki:  {enabled: true}     # DeepWiki
pylon_inventory: {enabled: true}     # inventory
otel_collector:  {enabled: true}     # OpenTelemetry collector
tracing_enabled: true
common:
  elitea_repo_type: internal         # internal plugin repository instead of the public one
  tools_enabled: true                # image with tools
```

Every pod runs as non-root with a read-only root filesystem, dropped capabilities and `RuntimeDefault` seccomp.
Resources, storage and `vpa_enabled` are set per component in `values.yaml`, which documents every value.

## Upgrade / uninstall

```bash
helm upgrade elitea oci://ghcr.io/eliteaai/charts/elitea --version <new> -n elitea -f prod-values.yaml
helm uninstall elitea -n elitea       # PVCs (databases, storage) will be deleted as well
```

Before upgrading read the release notes. Never change the `auth` / `main` secret keys.

## Troubleshooting

| Symptom | Check |
|---|---|
| `... is empty: set it` at install | A required secret is missing: set it or use `existingSecret` |
| `CreateContainerConfigError` | A key is missing from `existingSecret`: `kubectl -n elitea describe pod <pod>` |
| Pods `Pending` | PVC without StorageClass: `kubectl get pvc,sc`, set `*.storage.class` / `storageClass` |
| Login redirects loop over HTTPS | `app_proto: https`, `cookies_secure: "true"` and the right `app_host` |
| Ingress has no address | Controller for your cloud is missing (see Requirements), `kubectl describe ingress` |
| Passwords change on every Argo sync | `lookup` is unavailable: use `existingSecret` |

## Development

```bash
make lint      # helm lint --strict; adds charts/ci/test-values.yaml (dummy secrets) when VALS is the default
make template  # renders to build/render.yaml
```
