#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
K8S_DO="$SCRIPT_DIR/k8s-do"

grep -q 'arping -D -I "$ARP_IF"' "$K8S_DO"
grep -q 'owner_interface=' "$K8S_DO"
grep -q 'route_interface=' "$K8S_DO"
grep -q 'capture_interface=' "$K8S_DO"
grep -q 'arp_interface=' "$K8S_DO"
grep -q 'CAPTURE_SECONDS="${6:-10}"' "$K8S_DO"
grep -q 'arp_count".*-ge 1' "$K8S_DO"

echo '[PASS] egress-check uses ARP DAD duplicate probe and separates owner/route/capture/arp interfaces.'
