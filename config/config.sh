#!/usr/bin/env bash

# =========================================================
# cluster-ssh v2 configuration
# =========================================================

CLUSTER_SSH_USER="vmware-system-user"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
SSH_BIN="${SSH_BIN:-ssh}"

# static | supervisor | hybrid
# - static: existing local kubeconfig/private-key mappings
# - supervisor: discover Cluster API objects and secrets from Supervisor API
# - hybrid: static aliases plus Supervisor API discovery
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
# Supervisor API discovery mode
# -----------------------------------------------------------------
# Kubeconfig that can list Cluster API objects and read the workload
# cluster kubeconfig/SSH secrets in their namespaces.
SUPERVISOR_KUBECONFIG="/path/to/supervisor-kubeconfig"
SUPERVISOR_CLUSTER_RESOURCE="clusters.cluster.x-k8s.io"

KUBECONFIG_SECRET_SUFFIX="-kubeconfig"
KUBECONFIG_SECRET_KEY="value"
SSH_SECRET_SUFFIX="-ssh"
SSH_SECRET_KEY="ssh-privatekey"

# Optional short aliases for Supervisor cluster references.
# Requires Bash 4+.
declare -A CLUSTER_ALIASES=(
  # [dev-workload]="dev-namespace/tkg-example-dev-workload-cluster-001"
  # [stg-workload]="stg-namespace/tkg-example-stg-workload-cluster-001"
)

# -----------------------------------------------------------------
# Static/fallback mode: backward-compatible mappings
# -----------------------------------------------------------------
CLUSTERS=(
  dev-shared
  dev-workload
  stg-shared
  stg-workload
)

get_cluster_kubeconfig() {
  case "$1" in
    dev-shared)   echo "/srv/tanzu/file/ssh/kubeconfigs/tkg-example-dev-shared-cluster-001-kubeconfig" ;;
    dev-workload) echo "/srv/tanzu/file/ssh/kubeconfigs/tkg-example-dev-workload-cluster-001-kubeconfig" ;;
    stg-shared)   echo "/srv/tanzu/file/ssh/kubeconfigs/tkg-example-stg-shared-cluster-001-kubeconfig" ;;
    stg-workload) echo "/srv/tanzu/file/ssh/kubeconfigs/tkg-example-stg-workload-cluster-001-kubeconfig" ;;
    *) return 1 ;;
  esac
}

get_cluster_private_key() {
  case "$1" in
    dev-shared)   echo "/srv/tanzu/file/ssh/privatekey/tkg-example-dev-shared-cluster-001-ssh-privatekey" ;;
    dev-workload) echo "/srv/tanzu/file/ssh/privatekey/tkg-example-dev-workload-cluster-001-ssh-privatekey" ;;
    stg-shared)   echo "/srv/tanzu/file/ssh/privatekey/tkg-example-stg-shared-cluster-001-ssh-privatekey" ;;
    stg-workload) echo "/srv/tanzu/file/ssh/privatekey/tkg-example-stg-workload-cluster-001-ssh-privatekey" ;;
    *) return 1 ;;
  esac
}
