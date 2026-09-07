#!/usr/bin/env bash

# =========================================================
# cluster-ssh v3 configuration
# =========================================================

CLUSTER_SSH_USER="vmware-system-user"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
SSH_BIN="${SSH_BIN:-ssh}"

# static | supervisor | hybrid
CLUSTER_DISCOVERY_MODE="${CLUSTER_DISCOVERY_MODE:-static}"

KUBECTL_REQUEST_TIMEOUT="5s"
NODE_CACHE_TTL=20
CLUSTER_CACHE_TTL=30
ASSET_CACHE_TTL=300

CLUSTER_SSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cluster-ssh"
CLUSTER_SSH_KNOWN_HOSTS="${XDG_STATE_HOME:-$HOME/.local/state}/cluster-ssh/known_hosts"

CLUSTER_SSH_OPTS=(
  -o IdentitiesOnly=yes
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=2
)

# -----------------------------------------------------------------
# egress-check v3 defaults
# -----------------------------------------------------------------
# One Running Pod whose name starts with FIX_TOOL_POD_PREFIX is selected.
# When more than one Pod matches, use --pod to select one explicitly.
FIX_TOOL_NAMESPACE="fix-tool"
FIX_TOOL_POD_PREFIX="fix-tool"
EGRESS_CHECK_TIMEOUT=10

# -----------------------------------------------------------------
# Supervisor API discovery mode
# -----------------------------------------------------------------
SUPERVISOR_KUBECONFIG="/path/to/supervisor-kubeconfig"
SUPERVISOR_CLUSTER_RESOURCE="clusters.cluster.x-k8s.io"

KUBECONFIG_SECRET_SUFFIX="-kubeconfig"
KUBECONFIG_SECRET_KEY="value"
SSH_SECRET_SUFFIX="-ssh"
SSH_SECRET_KEY="ssh-privatekey"

declare -A CLUSTER_ALIASES=(
  # [dev-workload]="dev-namespace/tkg-example-dev-workload-cluster-001"
)

# -----------------------------------------------------------------
# Static/fallback mode
# Replace these examples with the files that actually exist.
# Sandbox example:
#   kubeconfig : /srv/tanzu/file/ssh/kubeconfigs/dev-workload.conf
#   private key: /srv/tanzu/file/ssh/privatekey/dev-workload.pem
# -----------------------------------------------------------------
CLUSTERS=(
  dev-workload
)

get_cluster_kubeconfig() {
  case "$1" in
    dev-workload)
      echo "/srv/tanzu/file/ssh/kubeconfigs/dev-workload.conf"
      ;;
    *) return 1 ;;
  esac
}

get_cluster_private_key() {
  case "$1" in
    dev-workload)
      echo "/srv/tanzu/file/ssh/privatekey/dev-workload.pem"
      ;;
    *) return 1 ;;
  esac
}
