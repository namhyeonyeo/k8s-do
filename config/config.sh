#!/usr/bin/env bash

# =========================================================
# k8s-do v3.2.5 configuration
# =========================================================

K8S_DO_USER="vmware-system-user"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
SSH_BIN="${SSH_BIN:-ssh}"

# static | supervisor | hybrid
CLUSTER_DISCOVERY_MODE="${CLUSTER_DISCOVERY_MODE:-static}"

KUBECTL_REQUEST_TIMEOUT="5s"
NODE_CACHE_TTL=20
CLUSTER_CACHE_TTL=30
ASSET_CACHE_TTL=300

K8S_DO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/k8s-do"
K8S_DO_KNOWN_HOSTS="${XDG_STATE_HOME:-$HOME/.local/state}/k8s-do/known_hosts"

K8S_DO_OPTS=(
  -o IdentitiesOnly=yes
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=2
)

# -----------------------------------------------------------------
# Static cluster auto-discovery
# -----------------------------------------------------------------
# Every regular file directly under STATIC_KUBECONFIG_DIR is discovered.
# The CLI cluster name is derived from the filename:
#   dev-workload.conf       -> dev-workload
#   prod-workload.kubeconfig -> prod-workload
#   stage-workload.yaml     -> stage-workload
#   test-workload           -> test-workload
#
# Recommended convention:
#   kubeconfig : <cluster-name>.conf (or .kubeconfig/.yaml/.yml/no extension)
#   private key: <cluster-name>.pem (or .key/no extension)
#
# This removes the need to maintain CLUSTERS=(...) and a case statement
# whenever a new kubeconfig is added.
STATIC_KUBECONFIG_DIR="/srv/k8s/file/ssh/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="/srv/k8s/file/ssh/privatekey"

# Optional legacy/fallback mapping.
# Keep these functions only when a cluster cannot follow the filename convention.
# get_cluster_kubeconfig() {
#   case "$1" in
#     special-cluster) echo "/some/other/path/special.conf" ;;
#     *) return 1 ;;
#   esac
# }
#
# get_cluster_private_key() {
#   case "$1" in
#     special-cluster) echo "/some/other/path/special.pem" ;;
#     *) return 1 ;;
#   esac
# }

# -----------------------------------------------------------------
# egress-check defaults
# -----------------------------------------------------------------
FIX_TOOL_NAMESPACE="fix-tool"
FIX_TOOL_POD_PREFIX="fix-tool"
EGRESS_CHECK_TIMEOUT=10
K8S_DO_DOCTOR_DIR="/tmp/k8s-do-doctor"
K8S_DO_EGRESS_DIR="/tmp/k8s-do-egress"

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
