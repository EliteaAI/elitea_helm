#!/usr/bin/env bash
# Quick start on a local cluster. Usage: ./install.sh [chart] [extra helm args...]
#   chart: path (default ../../charts) or oci://ghcr.io/eliteaai/charts/elitea --version <version>
set -euo pipefail
cd "$(dirname "$0")"

NS=${NS:-elitea}
RELEASE=${RELEASE:-elitea}
CHART=${1:-../../charts}
[ $# -gt 0 ] && shift

rand() { openssl rand 40 | base64 | tr '/+' '_-'; }

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Secrets are created once; re-running keeps the existing ones (changing the auth/main keys would break the data)
if ! kubectl -n "$NS" get secret elitea-secrets >/dev/null 2>&1; then
  ADMIN_PASSWORD=$(rand)
  kubectl -n "$NS" create secret generic elitea-secrets \
    --from-literal=postgres_user=elitea --from-literal=postgres_password="$(rand)" \
    --from-literal=redis_password="$(rand)" \
    --from-literal=rpc_hmac_key="$(rand)" --from-literal=event_hmac_key="$(rand)" \
    --from-literal=exposure_hmac_key="$(rand)" --from-literal=indexer_hmac_key="$(rand)" \
    --from-literal=mesh_hmac_key="$(rand)" \
    --from-literal=application_auth_secret_key="$(rand)" \
    --from-literal=default_admin_password="$ADMIN_PASSWORD" \
    --from-literal=application_main_secret_key="$(rand)" \
    --from-literal=secrets_master_key="$(openssl rand 32 | openssl base64 -A | tr '+/' '-_')"
  echo "Admin password: $ADMIN_PASSWORD"
fi

helm upgrade --install "$RELEASE" "$CHART" -n "$NS" -f values.yaml "$@"

cat <<MSG

Wait for the pods (first start pulls big images, can take 10+ minutes):
  kubectl -n $NS get pods -w
Then open the UI:
  kubectl -n $NS port-forward svc/pylon-main-svc 8080:8080     # http://localhost:8080
Admin password later: kubectl -n $NS get secret elitea-secrets -o jsonpath='{.data.default_admin_password}' | base64 -d
Clean up: helm -n $NS uninstall $RELEASE && kubectl delete namespace $NS
MSG
