#!/usr/bin/env bash
set -euo pipefail
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/bin" "$WORKDIR/kubeconfigs" "$WORKDIR/privatekey" "$WORKDIR/etc" "$WORKDIR/cache" "$WORKDIR/state"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cp "$SCRIPT_DIR/k8s-do" "$WORKDIR/bin/k8s-do"
chmod +x "$WORKDIR/bin/k8s-do"
cat > "$WORKDIR/etc/config.sh" <<CFG
K8S_DO_USER="vmware-system-user"
KUBECTL_BIN="$WORKDIR/bin/kubectl"
SSH_BIN="$WORKDIR/bin/ssh"
CLUSTER_DISCOVERY_MODE="static"
STATIC_KUBECONFIG_DIR="$WORKDIR/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="$WORKDIR/privatekey"
K8S_DO_CACHE_DIR="$WORKDIR/cache"
K8S_DO_KNOWN_HOSTS="$WORKDIR/state/known_hosts"
KUBECONFIG_SECRET_SUFFIX="-kubeconfig"
CFG
cat > "$WORKDIR/bin/kubectl" <<'KUBECTL'
#!/usr/bin/env bash
# k8s-do calls kubectl get nodes with a go-template, so this mock returns the already-rendered TSV.
if [[ "$*" == *"get nodes"* ]]; then
  printf 'node-a\t10.0.0.11\tTrue\tfalse\tv1.33.1\n'
fi
KUBECTL
chmod +x "$WORKDIR/bin/kubectl"
cat > "$WORKDIR/bin/ssh" <<'SSH'
#!/usr/bin/env bash
printf '%s\n' "$*" > /tmp/k8s-do-test-ssh-args
SSH
chmod +x "$WORKDIR/bin/ssh"
touch "$WORKDIR/kubeconfigs/tkg-example-prd-workload-cluster-001-kubeconfig"
touch "$WORKDIR/privatekey/tkg-example-prd-workload-cluster-001.pem"
export K8S_DO_CONFIG="$WORKDIR/etc/config.sh"
export PATH="$WORKDIR/bin:$PATH"
out=$(k8s-do __complete clusters)
[[ "$out" == "tkg-example-prd-workload-cluster-001" ]] || { echo "FAIL clusters: $out"; exit 1; }
k8s-do tkg-example-prd-workload-cluster-001 node-a >/dev/null || { echo "FAIL ssh resolve"; exit 1; }
grep -q 'tkg-example-prd-workload-cluster-001.pem' /tmp/k8s-do-test-ssh-args || { echo "FAIL key mapping"; exit 1; }
echo "[PASS] -kubeconfig suffix stripped and private key mapping works"
