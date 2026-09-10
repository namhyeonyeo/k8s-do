#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLI="$BUNDLE_DIR/k8s-do"
COMPLETION="$BUNDLE_DIR/k8s-do.completion"
TESTROOT=$(mktemp -d "${TMPDIR:-/tmp}/k8s-do-v32-test.XXXXXX")
trap 'rm -rf "$TESTROOT"' EXIT

mkdir -p "$TESTROOT/kubeconfigs" "$TESTROOT/privatekey" "$TESTROOT/bin" "$TESTROOT/cache" "$TESTROOT/state"

: > "$TESTROOT/kubeconfigs/dev-workload.conf"
: > "$TESTROOT/kubeconfigs/prod-workload.kubeconfig"
: > "$TESTROOT/kubeconfigs/stage-workload"
: > "$TESTROOT/privatekey/dev-workload.pem"
: > "$TESTROOT/privatekey/prod-workload.key"
: > "$TESTROOT/privatekey/stage-workload"
chmod 600 "$TESTROOT/privatekey"/*

cat > "$TESTROOT/bin/kubectl" <<'MOCK_KUBECTL'
#!/usr/bin/env bash
set -Eeuo pipefail
kc=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "--kubeconfig" ]]; then
    kc="${args[$((i+1))]}"
  fi
done

if [[ " $* " == *" get nodes "* ]]; then
  case "$(basename "$kc")" in
    dev-workload.conf)
      printf 'dev-cp-01\t10.10.0.11\tTrue\tfalse\tv1.30.1\n'
      printf 'dev-worker-01\t10.10.0.21\tTrue\tfalse\tv1.30.1\n'
      ;;
    prod-workload.kubeconfig)
      printf 'prod-cp-01\t10.20.0.11\tTrue\tfalse\tv1.30.1\n'
      printf 'prod-worker-01\t10.20.0.21\tTrue\tfalse\tv1.30.1\n'
      printf 'prod-worker-02\t10.20.0.22\tFalse\ttrue\tv1.30.1\n'
      ;;
    stage-workload)
      printf 'stage-no-ip\t-\tTrue\tfalse\tv1.30.1\n'
      printf 'stage-worker-01\t10.30.0.21\tTrue\tfalse\tv1.30.1\n'
      ;;
    *) exit 1 ;;
  esac
fi
MOCK_KUBECTL

cat > "$TESTROOT/bin/ssh" <<MOCK_SSH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TESTROOT/ssh.log"
exit 0
MOCK_SSH
chmod +x "$TESTROOT/bin/kubectl" "$TESTROOT/bin/ssh"

cat > "$TESTROOT/config.sh" <<TEST_CONFIG
K8S_DO_USER="vmware-system-user"
KUBECTL_BIN="$TESTROOT/bin/kubectl"
SSH_BIN="$TESTROOT/bin/ssh"
CLUSTER_DISCOVERY_MODE="static"
STATIC_KUBECONFIG_DIR="$TESTROOT/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="$TESTROOT/privatekey"
K8S_DO_CACHE_DIR="$TESTROOT/cache"
K8S_DO_KNOWN_HOSTS="$TESTROOT/state/known_hosts"
NODE_CACHE_TTL=20
TEST_CONFIG

export K8S_DO_CONFIG="$TESTROOT/config.sh"

clusters=$("$CLI" __complete clusters)
[[ "$clusters" == $'dev-workload\nprod-workload\nstage-workload' ]]

prod_table=$("$CLI" __complete nodes prod-workload)
for expected in \
  'NODE' 'INTERNAL-IP' \
  'prod-cp-01' '10.20.0.11' \
  'prod-worker-01' '10.20.0.21' \
  'prod-worker-02' '10.20.0.22' \
  'NotReady' 'Disabled'; do
  grep -Fq "$expected" <<<"$prod_table"
done

prod_values=$("$CLI" __complete node-values prod-workload)
for expected in prod-cp-01 prod-worker-01 prod-worker-02; do
  grep -Fxq "$expected" <<<"$prod_values"
done
! grep -Fxq '10.20.0.21' <<<"$prod_values"

stage_table=$("$CLI" __complete nodes stage-workload)
grep -Fq 'stage-no-ip' <<<"$stage_table"
grep -Fq 'stage-worker-01' <<<"$stage_table"
grep -Fq '10.30.0.21' <<<"$stage_table"

grep -Fxq 'stage-no-ip' < <("$CLI" __complete node-values stage-workload)

"$CLI" check prod-workload prod-worker-01 >/dev/null
grep -Fq -- "-i $TESTROOT/privatekey/prod-workload.key" "$TESTROOT/ssh.log"
grep -Fq -- 'vmware-system-user@10.20.0.21' "$TESTROOT/ssh.log"

# IP input is still accepted, even though IPs are no longer separate completion values.
"$CLI" check prod-workload 10.20.0.22 >/dev/null
grep -Fq -- 'vmware-system-user@10.20.0.22' "$TESTROOT/ssh.log"

export K8S_DO_BIN="$CLI"
# shellcheck disable=SC1090
source "$COMPLETION"
COMP_WORDS=(k8s-do prod-workload '')
COMP_CWORD=2
COMP_TYPE=9
_k8s_do_completion
completion_output=$(printf '%s\n' "${COMPREPLY[@]}")
for expected in prod-cp-01 prod-worker-01 prod-worker-02; do
  grep -Fxq "$expected" <<<"$completion_output"
done
! grep -Fxq '10.20.0.11' <<<"$completion_output"

echo '[PASS] /srv/k8s path is configured in config.sh'
grep -Fq '/srv/k8s/file/ssh/kubeconfigs' "$BUNDLE_DIR/config.sh"
grep -Fq '/srv/k8s/file/ssh/privatekey' "$BUNDLE_DIR/config.sh"

echo '[PASS] static kubeconfig directory discovery'
echo '[PASS] cluster-name completion'
echo '[PASS] node completion table displays NODE and INTERNAL-IP per row'
echo '[PASS] bash completion inserts node names only'
echo '[PASS] direct node IP input is still supported'
echo '[PASS] private-key filename mapping'
echo '[PASS] selected node resolves to the expected SSH IP'
echo '[PASS] bash completion wrapper'
