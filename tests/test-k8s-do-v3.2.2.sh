#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/kubeconfigs" "$TMP/privatekey" "$TMP/cache" "$TMP/state"

cat > "$TMP/config.sh" <<CFG
K8S_DO_USER="vmware-system-user"
KUBECTL_BIN="$TMP/bin/kubectl"
SSH_BIN="$TMP/bin/ssh"
CLUSTER_DISCOVERY_MODE="static"
KUBECTL_REQUEST_TIMEOUT="5s"
NODE_CACHE_TTL=0
K8S_DO_CACHE_DIR="$TMP/cache"
K8S_DO_KNOWN_HOSTS="$TMP/state/known_hosts"
STATIC_KUBECONFIG_DIR="$TMP/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="$TMP/privatekey"
CFG

touch "$TMP/kubeconfigs/tkg-example-prd-workload-cluster-001-kubeconfig"
touch "$TMP/kubeconfigs/tkg-example-prd-shared-cluster-001-kubeconfig"
touch "$TMP/privatekey/tkg-example-prd-workload-cluster-001-ssh-privatekey"
touch "$TMP/privatekey/tkg-example-prd-shared-cluster-001-ssh-privatekey"
chmod 600 "$TMP/privatekey"/*

cat > "$TMP/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == *"get nodes"* ]]; then
  cat <<'NODES'
tkg-example-prd-workload-cluster-001-md-0-a1b2c-d3e4f-k6ncv	10.50.93.46	True	false	v1.33.1+vmware.1-fips
tkg-example-prd-workload-cluster-001-md-0-a1b2c-d3e4f-psqfs	10.50.93.50	True	false	v1.33.1+vmware.1-fips
tkg-example-prd-workload-cluster-001-g5h6i-j7k8l	10.50.93.69	True	false	v1.33.1+vmware.1-fips
NODES
  exit 0
fi
exit 0
MOCK
chmod +x "$TMP/bin/kubectl"

cat > "$TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
echo "MOCK_SSH $*"
MOCK
chmod +x "$TMP/bin/ssh"

export K8S_DO_CONFIG="$TMP/config.sh"
out="$($ROOT/k8s-do __complete clusters)"
[[ "$out" == *"tkg-example-prd-workload-cluster-001"* ]]
[[ "$out" != *"workload-cluster-001-kubeconfig"* ]]

nodes="$($ROOT/k8s-do __complete nodes tkg-example-prd-workload-cluster-001)"
[[ "$nodes" == *"tkg-example-prd-workload-cluster-001-md-0-a1b2c-d3e4f-k6ncv"* ]]
[[ "$nodes" != *"INDEX"* ]]
[[ "$nodes" != *"INTERNAL-IP"* ]]
[[ "$nodes" != *"Ready"* ]]

table="$($ROOT/k8s-do __complete node-table tkg-example-prd-workload-cluster-001)"
[[ "$table" == *"INDEX"* ]]
[[ "$table" == *"10.50.93.46"* ]]

ssh_out="$($ROOT/k8s-do tkg-example-prd-workload-cluster-001 tkg-example-prd-workload-cluster-001-md-0-a1b2c-d3e4f-k6ncv)"
[[ "$ssh_out" == *"tkg-example-prd-workload-cluster-001-ssh-privatekey"* ]]
[[ "$ssh_out" == *"vmware-system-user@10.50.93.46"* ]]

echo "[PASS] kubeconfig -kubeconfig suffix stripped"
echo "[PASS] private key -ssh-privatekey suffix resolved"
echo "[PASS] __complete nodes is machine-readable only"
echo "[PASS] __complete node-table is human-readable"
echo "[PASS] SSH target resolved by node name"
