# k8s-do v3.1 설치 및 Egress 통합 진단 Runbook

## 1. v3.1 변경사항

`egress-check`가 다음 작업을 하나의 명령에서 수행한다.

1. 지정한 클러스터의 kubeconfig 해석
2. `fix-tool` Namespace에서 이름이 `fix-tool`로 시작하는 Running Pod 자동 탐색
3. Pod 이름, Pod IP, Pod가 위치한 Node 조회
4. 지정한 Egress Node에 SSH 연결
5. Egress IP의 로컬 소유 여부와 실제 외부 route interface 확인
6. 실제 route interface에서 ARP 응답 MAC 수집
7. Egress Node에서 tcpdump와 conntrack 감시 시작
8. fix-tool Pod 내부에서 목적지 TCP 연결 실행
9. Pod 트래픽, Egress IP SNAT, return traffic 증거 판정
10. 전체 결과를 로그 파일에 저장

Node 검사는 SSH, Pod 조회와 통신 발생은 `kubectl exec`를 사용한다.

### Static kubeconfig 자동 탐색 (v3.1)

기존 v3는 `CLUSTERS=(dev-workload)`와 `get_cluster_kubeconfig()`의 `case`에 클러스터를 직접 등록해야 했다.
따라서 kubeconfig 디렉터리에 파일이 여러 개 있어도 등록되지 않은 클러스터는 CLI가 알 수 없었다.

v3.1은 아래 두 디렉터리를 기준으로 자동 탐색한다.

```bash
STATIC_KUBECONFIG_DIR="/srv/k8s/file/ssh/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="/srv/k8s/file/ssh/privatekey"
```

권장 파일명 규칙:

```text
kubeconfigs/<cluster-name>.conf
privatekey/<cluster-name>.pem
```

다음 suffix는 CLI cluster 이름에서 자동 제거된다.

```text
.conf
.kubeconfig
.yaml
.yml
```

예시:

```text
/srv/k8s/file/ssh/kubeconfigs/dev-workload.conf
  -> k8s-do dev-workload

/srv/k8s/file/ssh/kubeconfigs/prod-workload.kubeconfig
  -> k8s-do prod-workload
```

확인:

```bash
k8s-do list
k8s-do __complete clusters
```

파일 내용에서 Kubernetes Cluster 이름을 추론하는 방식은 kubeconfig의 context/cluster entry 이름이 환경마다 다를 수 있으므로 기본 동작으로 사용하지 않는다. 따라서 **파일명 stem을 CLI의 안정적인 cluster 식별자로 사용하는 것을 권장**한다.

### Node 이름/IP 자동완성 검증 (v3.1)

Node completion은 해당 cluster kubeconfig로 다음 정보를 조회한다.

```text
metadata.name
status.addresses[type=InternalIP]
Ready condition
spec.unschedulable
kubeletVersion
```

직접 확인:

```bash
k8s-do nodes <cluster>
k8s-do __complete nodes <cluster>
```

실제 Bash completion 확인:

```bash
k8s-do <cluster> <TAB><TAB>
k8s-do check <cluster> <TAB><TAB>
```

Node cache TTL 기본값은 20초다. 노드 증설/삭제 직후 completion을 즉시 갱신하려면:

```bash
k8s-do refresh <cluster>
```

또는 `k8s-do nodes <cluster>`는 강제 refresh를 수행한다.

InternalIP가 없는 Node는 Node 이름은 completion에 표시되지만 잘못된 IP placeholder `-`는 표시하지 않도록 보완했다.

---

## 2. 배포 파일

```text
k8s-do-v3
k8s-do-v3.completion
config-v3.sh
```

구문 검사:

```bash
bash -n k8s-do-v3
bash -n k8s-do-v3.completion
bash -n config-v3.sh
```

---

## 3. 기존 v2 백업

```bash
BACKUP_DIR="/root/k8s-do-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp -a /usr/local/bin/k8s-do \
  "$BACKUP_DIR/k8s-do" 2>/dev/null || true

cp -a /etc/k8s-do/config.sh \
  "$BACKUP_DIR/config.sh" 2>/dev/null || true

cp -a /etc/bash_completion.d/k8s-do \
  "$BACKUP_DIR/k8s-do.completion" 2>/dev/null || true

echo "$BACKUP_DIR"
```

---

## 4. 교체 대상

| 운영 경로 | v3 원본 |
|---|---|
| `/usr/local/bin/k8s-do` | `k8s-do-v3` |
| `/etc/bash_completion.d/k8s-do` | `k8s-do-v3.completion` |
| `/etc/k8s-do/config.sh` | `config-v3.sh`를 환경에 맞게 수정한 파일 |

실행 파일과 completion은 바로 교체할 수 있다.

`config.sh`는 기존 실제 kubeconfig/private key 경로를 유지해야 하므로 무조건 덮어쓰지 않는다.

---

## 5. 샌드박스용 config 확인

제공된 `config-v3.sh`는 다음 샌드박스 구조를 기본 예시로 사용한다.

```text
cluster alias: dev-workload
kubeconfig   : /srv/k8s/file/ssh/kubeconfigs/dev-workload.conf
private key  : /srv/k8s/file/ssh/privatekey/dev-workload.pem
```

실제 파일 확인:

```bash
ls -l /srv/k8s/file/ssh/kubeconfigs/dev-workload.conf
ls -l /srv/k8s/file/ssh/privatekey/dev-workload.pem
```

파일명이 다르면 `config-v3.sh`의 다음 함수를 수정한다.

```bash
get_cluster_kubeconfig()
get_cluster_private_key()
```

기본 Egress 테스트 Pod 설정:

```bash
FIX_TOOL_NAMESPACE="fix-tool"
FIX_TOOL_POD_PREFIX="fix-tool"
EGRESS_CHECK_TIMEOUT=10
```

---

## 6. 설치

```bash
install -d -m 750 /etc/k8s-do
install -d -m 755 /etc/bash_completion.d

install -m 755 \
  k8s-do-v3 \
  /usr/local/bin/k8s-do

install -m 644 \
  k8s-do-v3.completion \
  /etc/bash_completion.d/k8s-do
```

config는 검토한 뒤 설치한다.

```bash
cp config-v3.sh /tmp/config-v3.sh
vi /tmp/config-v3.sh
bash -n /tmp/config-v3.sh

install -m 640 \
  /tmp/config-v3.sh \
  /etc/k8s-do/config.sh
```

---

## 7. completion 반영

v3 completion은 `_init_completion`에 의존하지 않는다.

```bash
source /etc/bash_completion.d/k8s-do
complete -p k8s-do
```

새 로그인에도 자동 로딩되지 않는 환경이면 `/root/.bashrc` 또는 사용자 `.bashrc`에 추가한다.

```bash
cat >> ~/.bashrc <<'BASHRC'
if [[ -f /etc/bash_completion.d/k8s-do ]]; then
  source /etc/bash_completion.d/k8s-do
fi
BASHRC
```

---

## 8. 설치 후 기본 검증

```bash
k8s-do version
k8s-do list
k8s-do nodes dev-workload
k8s-do __complete clusters
k8s-do __complete nodes dev-workload
```

예상 버전:

```text
k8s-do 3.1.0
```

fix-tool Pod 확인:

```bash
kubectl \
  --kubeconfig /srv/k8s/file/ssh/kubeconfigs/dev-workload.conf \
  -n fix-tool get pods -o wide
```

Running 상태이며 이름이 `fix-tool`로 시작하는 Pod가 정확히 하나 있어야 자동 선택된다.

---

## 9. Egress 통합 진단 실행

```bash
k8s-do egress-check \
  dev-workload \
  <egress-node-name> \
  --egress-ip 10.60.196.92 \
  --dst 10.60.196.60 \
  --port 22
```

기본적으로 자동 사용되는 값:

```text
namespace : fix-tool
pod prefix: fix-tool
timeout   : 10 seconds
```

특정 Pod를 지정하려면:

```bash
k8s-do egress-check \
  dev-workload \
  <egress-node-name> \
  --egress-ip 10.60.196.92 \
  --dst 10.60.196.60 \
  --port 22 \
  --pod fix-tool-xxxxxxxxxx-yyyyy
```

특정 컨테이너:

```bash
... --container netshoot
```

결과 파일 지정:

```bash
... --output /tmp/egress-check.log
```

외부 route interface 자동 탐지가 잘못된 경우에만:

```bash
... --iface eth0
```

---

## 10. Pod 자동 선택 규칙

```text
Running fix-tool prefix Pod 0개
→ 명령 실패

Running fix-tool prefix Pod 1개
→ 자동 선택

Running fix-tool prefix Pod 2개 이상
→ 임의 선택하지 않고 실패
→ --pod로 정확한 Pod 지정
```

---

## 11. Pod 이미지 요구사항

Pod 내부 TCP 테스트 명령은 다음 우선순위를 사용한다.

```text
1. nc
2. curl telnet://
3. timeout + bash /dev/tcp
```

최소 하나가 있어야 한다. netshoot 계열 이미지 사용을 권장한다.

확인:

```bash
kubectl --kubeconfig <kubeconfig> -n fix-tool exec <pod> -- \
  sh -c 'command -v nc || command -v curl || { command -v timeout && command -v bash; }'
```

---

## 12. Egress Node 요구사항

필수:

```text
ip
ssh daemon
```

증거 수집 권장:

```text
arping
tcpdump
conntrack
timeout
sudo -n 권한
```

도구 확인:

```bash
k8s-do exec dev-workload <egress-node> -- \
  'for c in ip arping tcpdump conntrack timeout; do command -v "$c" || echo "MISSING: $c"; done'
```

sudo 확인:

```bash
k8s-do exec dev-workload <egress-node> -- \
  'sudo -n true && echo SUDO_OK || echo SUDO_PASSWORD_REQUIRED'
```

sudo 또는 capability가 없으면 tcpdump/conntrack 증거가 제한될 수 있다.

---

## 13. 결과 해석

### 정상에 가까운 결과

```text
[PASS] Egress IP is present on the selected Egress Node.
[PASS] TCP connectivity from fix-tool/... succeeded.
[PASS] Outbound traffic with source Egress IP ... was observed.
[PASS] Return traffic to Egress IP ... was observed.
```

### SNAT 미확인

```text
[FAIL] Expected SNAT source ... was not observed on the external interface.
```

가능한 원인:

- 잘못된 Egress Node를 지정
- Egress 정책의 Namespace/Pod selector 불일치
- CNI에서 다른 Node에 Egress IP를 배치
- 실제 route interface 자동 탐지 오류
- tcpdump 권한 부족
- CNI dataplane에서 예상과 다른 지점에서 NAT 처리

### 복수 MAC 응답

```text
[CRITICAL] Multiple MAC addresses responded for the Egress IP.
```

IP 충돌 강력 의심이며 응답 MAC을 vCenter, NSX, 물리 스위치 MAC table에서 역추적한다.

단, proxy ARP나 네트워크 가상화 구현에 따라 ARP 결과만으로 최종 확정하지 않는다.

### Pod 접속 성공, Pod IP가 Egress Node에서 안 보임

Pod IP가 Egress Node에 들어오기 전에 overlay 또는 CNI dataplane에서 캡슐화/NAT될 수 있다. 외부 interface에서 Egress IP source가 확인되는지가 더 중요한 증거다.

---

## 14. Exit code

| Code | 의미 |
|---:|---|
| 0 | Egress IP 존재, Pod 테스트 성공, Egress IP SNAT 증거 확인 |
| 1 | 입력/설정/Pod 탐색/SSH/capture 준비 오류 |
| 2 | Pod 연결 실패, Egress IP 미소유 또는 SNAT 증거 미확인 |
| 3 | 복수 ARP MAC 감지 |

실행 후:

```bash
k8s-do egress-check ...
echo $?
```

---

## 15. 안전성

v3 `egress-check`는 다음 변경 작업을 수행하지 않는다.

```text
Egress IP 해제
conntrack 삭제
iptables/nftables 변경
interface 변경
node cordon/drain
service restart
```

읽기 전용 패킷/상태 수집과 TCP connect 테스트만 수행한다.


## v3.2.4 completion behavior note

Bash Tab completion is intentionally non-interactive. It does not print the node table and it does not call kubectl when node cache is missing or stale. Run `k8s-do nodes <cluster>` once to refresh the node cache, then use Tab completion for node names. This prevents kubeconfig auth plugins, SSH prompts, or employee-number prompts from appearing during Tab completion.
