# k8s-do v3.1 기능 정리 및 사용법

> 작성 기준: 업로드된 `cluster-ssh v3.1` 구현체를 기준으로 기능을 확인했다.  
> 반영 변경사항: 명령어 이름은 `cluster-ssh` 대신 `k8s-do` 기준으로 정리했고, 기본 파일 경로는 기존 `/srv/tanzu`에서 `/srv/k8s`로 변경했다.

---

## 1. 도구 목적

`k8s-do`는 Kubernetes 운영자가 여러 Workload Cluster의 노드에 빠르게 접근하고, 노드 상태 확인, 원격 명령 실행, 노드 단위 진단, Egress 통신 검증을 수행하기 위한 Bash 기반 CLI이다.

초기 목적은 `SSH 접속 자동화`에 가까웠지만 v3.1 기준으로는 다음 기능까지 포함한다.

- kubeconfig 기반 클러스터 자동 탐색
- 클러스터 목록 조회
- 노드 목록 조회
- 노드명 자동완성
- 노드명/IP/index 기반 SSH 접속
- SSH reachability 확인
- 원격 명령 실행
- 노드 단위 doctor 진단
- fix-tool Pod 기반 Egress 통신 검증
- Node/Cluster 캐시 refresh
- Bash completion 지원

따라서 명령어 이름은 `cluster-ssh`보다 `k8s-do`가 더 적합하다. `ssh`뿐 아니라 `check`, `exec`, `doctor`, `egress-check`까지 수행하므로 “Kubernetes에서 운영 작업을 수행한다”는 의미가 더 잘 맞는다.

---

## 2. 권장 디렉터리 구조

기본 경로는 `/srv/k8s` 기준으로 정리한다.

```text
/srv/k8s/file/ssh
├── kubeconfigs
│   ├── dev-workload.conf
│   ├── stg-workload.conf
│   └── prod-workload.conf
└── privatekey
    ├── dev-workload.pem
    ├── stg-workload.pem
    └── prod-workload.pem
```

권장 파일명 규칙은 다음과 같다.

```text
kubeconfig : /srv/k8s/file/ssh/kubeconfigs/<cluster-name>.conf
private key: /srv/k8s/file/ssh/privatekey/<cluster-name>.pem
```

예시:

```text
/srv/k8s/file/ssh/kubeconfigs/dev-workload.conf
/srv/k8s/file/ssh/privatekey/dev-workload.pem
```

위와 같이 배치하면 CLI에서는 다음처럼 사용한다.

```bash
k8s-do dev-workload
k8s-do nodes dev-workload
k8s-do check dev-workload worker-node-01
```

---

## 3. 기본 설정 파일

기본 설정 파일 위치는 다음과 같다.

```bash
/etc/k8s-do/config.sh
```

다른 위치의 설정 파일을 사용하려면 환경변수로 지정할 수 있다.

```bash
export K8S_DO_CONFIG=/path/to/config.sh
k8s-do list
```

핵심 설정 예시는 다음과 같다.

```bash
K8S_DO_USER="vmware-system-user"
KUBECTL_BIN="kubectl"
SSH_BIN="ssh"

# static | supervisor | hybrid
CLUSTER_DISCOVERY_MODE="static"

KUBECTL_REQUEST_TIMEOUT="5s"
NODE_CACHE_TTL=20
CLUSTER_CACHE_TTL=30
ASSET_CACHE_TTL=300

K8S_DO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/k8s-do"
K8S_DO_KNOWN_HOSTS="${XDG_STATE_HOME:-$HOME/.local/state}/k8s-do/known_hosts"

STATIC_KUBECONFIG_DIR="/srv/k8s/file/ssh/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="/srv/k8s/file/ssh/privatekey"
```

---

## 4. 클러스터 탐색 방식

### 4.1 static 모드

`static` 모드는 특정 디렉터리 안의 kubeconfig 파일을 자동 탐색한다.

```bash
CLUSTER_DISCOVERY_MODE="static"
STATIC_KUBECONFIG_DIR="/srv/k8s/file/ssh/kubeconfigs"
STATIC_PRIVATE_KEY_DIR="/srv/k8s/file/ssh/privatekey"
```

v3.1 이전 구조처럼 `CLUSTERS=(dev-workload)` 또는 `case dev-workload)`에 직접 등록하는 방식이 아니다.

아래 파일들이 존재한다고 가정한다.

```text
/srv/k8s/file/ssh/kubeconfigs/dev-workload.conf
/srv/k8s/file/ssh/kubeconfigs/stg-workload.kubeconfig
/srv/k8s/file/ssh/kubeconfigs/prod-workload.yaml
```

CLI에서는 다음 cluster 이름으로 인식한다.

```text
dev-workload
stg-workload
prod-workload
```

자동 제거되는 확장자는 다음과 같다.

```text
.conf
.kubeconfig
.yaml
.yml
```

### 4.2 supervisor 모드

`supervisor` 모드는 Supervisor Cluster의 Kubernetes API를 통해 workload cluster 정보를 조회하는 방식이다.

관련 설정:

```bash
CLUSTER_DISCOVERY_MODE="supervisor"
SUPERVISOR_KUBECONFIG="/path/to/supervisor-kubeconfig"
SUPERVISOR_CLUSTER_RESOURCE="clusters.cluster.x-k8s.io"
KUBECONFIG_SECRET_SUFFIX="-kubeconfig"
KUBECONFIG_SECRET_KEY="value"
SSH_SECRET_SUFFIX="-ssh"
SSH_SECRET_KEY="ssh-privatekey"
```

이 모드에서는 Supervisor에 있는 Cluster 리소스와 Secret을 기준으로 workload cluster kubeconfig와 SSH key를 가져오는 구조다.

### 4.3 hybrid 모드

`hybrid`는 static과 supervisor를 같이 사용하는 방식이다.

```bash
CLUSTER_DISCOVERY_MODE="hybrid"
```

운영에서는 우선 `/srv/k8s`에 kubeconfig/key를 명시적으로 관리하는 `static` 모드가 가장 단순하고 예측 가능하다. Supervisor 기반 자동 조회까지 필요하면 `hybrid`를 검토하면 된다.

---

## 5. 명령어 목록

### 5.1 버전 확인

```bash
k8s-do version
```

예상 출력:

```text
k8s-do 3.2.0
```

기능 기준은 v3.1이며, `/srv/k8s` 경로 변경과 명령어 rename 반영본은 v3.2.0으로 표기했다.

---

### 5.2 도움말

```bash
k8s-do help
```

또는:

```bash
k8s-do --help
```

---

### 5.3 클러스터 목록 조회

```bash
k8s-do list
```

기능:

- static kubeconfig 디렉터리 탐색
- supervisor/hybrid 모드일 경우 Supervisor Cluster 조회
- CLI가 인식 가능한 cluster ref 목록 출력

예시:

```text
SOURCE      CLUSTER
static      dev-workload
static      stg-workload
static      prod-workload
```

---

### 5.4 노드 목록 조회

```bash
k8s-do nodes <cluster>
```

예시:

```bash
k8s-do nodes dev-workload
```

조회 정보:

- index
- node name
- InternalIP
- Ready 상태
- Scheduling 가능 여부
- kubelet version

예상 출력:

```text
INDEX NODE                                                   INTERNAL-IP      STATUS     SCHEDULING   VERSION
----- ----                                                   -----------      ------     ----------   -------
1     worker-node-01                                         10.10.0.21       Ready      Enabled      v1.30.1
2     worker-node-02                                         10.10.0.22       Ready      Enabled      v1.30.1
3     worker-node-03                                         10.10.0.23       NotReady   Disabled     v1.30.1
```

`nodes` 명령은 kubeconfig를 이용해 다음 데이터를 조회한다.

```text
metadata.name
status.addresses[type=InternalIP]
status.conditions[type=Ready]
spec.unschedulable
status.nodeInfo.kubeletVersion
```

---

### 5.5 SSH 접속

노드명을 지정해서 접속한다.

```bash
k8s-do <cluster> <node-name>
```

예시:

```bash
k8s-do dev-workload worker-node-01
```

IP로도 접속할 수 있다.

```bash
k8s-do dev-workload 10.10.0.21
```

index로도 접속할 수 있다.

```bash
k8s-do dev-workload 1
```

노드를 지정하지 않으면 interactive 선택 모드로 진입한다.

```bash
k8s-do dev-workload
```

`fzf`가 설치되어 있으면 fzf 기반 선택 메뉴를 사용하고, 없으면 index/node/ip 입력 방식으로 동작한다.

---

### 5.6 SSH 연결 확인

```bash
k8s-do check <cluster> <node-name|node-ip|index>
```

예시:

```bash
k8s-do check dev-workload worker-node-01
```

성공 시:

```text
[OK] cluster=dev-workload node=worker-node-01 ip=10.10.0.21 ssh=reachable
```

실패 시:

```text
[FAIL] cluster=dev-workload node=worker-node-01 ip=10.10.0.21 ssh=unreachable rc=255
```

이 명령은 실제 장애 대응 전에 SSH 접근 가능 여부를 빠르게 확인할 때 유용하다.

---

### 5.7 원격 명령 실행

```bash
k8s-do exec <cluster> <node-name|node-ip|index> -- '<remote command>'
```

예시:

```bash
k8s-do exec dev-workload worker-node-01 -- 'hostname'
```

kubelet 로그 확인:

```bash
k8s-do exec dev-workload worker-node-01 -- 'sudo journalctl -u kubelet -n 100 --no-pager'
```

container runtime 상태 확인:

```bash
k8s-do exec dev-workload worker-node-01 -- 'sudo crictl ps | head'
```

디스크 사용률 확인:

```bash
k8s-do exec dev-workload worker-node-01 -- 'df -h'
```

---

### 5.8 Node doctor 진단

```bash
k8s-do doctor <cluster> <node-name|node-ip|index> [--output <file>]
```

예시:

```bash
k8s-do doctor dev-workload worker-node-01
```

결과 파일명을 지정할 수도 있다.

```bash
k8s-do doctor dev-workload worker-node-01 --output /tmp/worker-node-01-doctor.log
```

수집하는 정보:

- `kubectl describe node <node>`
- 해당 노드에 올라간 전체 Pod 목록
- Node 관련 Event
- 원격 노드의 hostname
- uptime
- OS/kernel 정보
- IP 주소 정보
- route 정보
- disk 사용량
- memory 사용량
- kubelet 상태
- containerd 상태
- 최근 kubelet 로그
- 최근 containerd 로그

기본 결과 파일명 예시:

```text
k8s-do-doctor-dev-workload-worker-node-01-20260910-094500.log
```

---

### 5.9 Egress 통신 검증

```bash
k8s-do egress-check <cluster> <node-name|node-ip|index> \
  --egress-ip <egress-ip> \
  --dst <destination-ip> \
  --port <destination-port>
```

예시:

```bash
k8s-do egress-check dev-workload worker-node-01 \
  --egress-ip 10.60.93.191 \
  --dst 10.60.191.31 \
  --port 8522
```

기본값:

```bash
FIX_TOOL_NAMESPACE="fix-tool"
FIX_TOOL_POD_PREFIX="fix-tool"
EGRESS_CHECK_TIMEOUT=10
```

옵션:

```text
--egress-ip <ip>       확인할 Egress IP
--dst <ip>             목적지 IP
--port <port>          목적지 TCP port
--namespace <ns>       통신 테스트 Pod가 있는 Namespace
--pod-prefix <prefix>  Running Pod 자동 탐색 prefix
--pod <name>           특정 Pod 지정
--container <name>     특정 Container 지정
--iface <interface>    tcpdump를 수행할 Interface 지정
--timeout <seconds>    통신/캡처 timeout
--output <file>        결과 로그 파일 지정
```

수행 흐름:

1. cluster kubeconfig 해석
2. fix-tool Namespace에서 Running Pod 탐색
3. Pod IP와 해당 Pod가 위치한 Node 확인
4. 지정한 Egress Node에 SSH 접속
5. Egress IP가 해당 Node에 존재하는지 확인
6. route interface 확인
7. ARP 응답 MAC 수집
8. tcpdump와 conntrack 감시 시작
9. Pod 내부에서 목적지로 TCP 연결 발생
10. Pod 트래픽, Egress IP SNAT, return traffic 확인
11. 결과를 PASS/WARN/FAIL/CRITICAL로 정리

결과 판단 예시:

```text
[PASS] Egress IP is present on the selected Egress Node.
[PASS] TCP connectivity from fix-tool/fix-tool-xxxxx to 10.60.191.31:8522 succeeded.
[PASS] Pod-originated traffic was observed on the Egress Node.
[PASS] Outbound traffic with source Egress IP 10.60.93.191 was observed.
[PASS] Return traffic to Egress IP 10.60.93.191 was observed.
```

중복 IP가 의심될 경우:

```text
[CRITICAL] Multiple MAC addresses responded for the Egress IP. Duplicate ownership is strongly suspected.
```

기본 결과 파일명 예시:

```text
k8s-do-egress-dev-workload-20260910-094500.log
```

---

### 5.10 캐시 갱신

전체 캐시 삭제:

```bash
k8s-do refresh
```

특정 cluster의 node/cache만 삭제:

```bash
k8s-do refresh dev-workload
```

노드를 새로 증설했는데 자동완성 목록에 바로 보이지 않으면 다음을 수행한다.

```bash
k8s-do refresh dev-workload
```

또는:

```bash
k8s-do nodes dev-workload
```

`NODE_CACHE_TTL` 기본값은 20초다.

---

## 6. Bash completion

### 6.1 설치 위치

```bash
/etc/bash_completion.d/k8s-do
```

설치 후 현재 shell에 즉시 반영하려면:

```bash
source /etc/bash_completion.d/k8s-do
```

등록 확인:

```bash
complete -p k8s-do
```

---

### 6.2 Cluster 자동완성

```bash
k8s-do <TAB><TAB>
```

예상 후보:

```text
check         doctor        egress-check  exec          help          list          nodes         refresh       version
dev-workload  stg-workload  prod-workload
```

---

### 6.3 Node 자동완성

다음 위치에서 노드 자동완성을 사용할 수 있다.

```bash
k8s-do dev-workload <TAB><TAB>
k8s-do check dev-workload <TAB><TAB>
k8s-do exec dev-workload <TAB><TAB>
k8s-do doctor dev-workload <TAB><TAB>
k8s-do egress-check dev-workload <TAB><TAB>
```

개선된 방식은 자동완성 표시 시 Node와 InternalIP를 같은 라인에 보여주는 것이다.

```text
NODE                                                   INTERNAL-IP      STATUS     SCHEDULING   VERSION
----                                                   -----------      ------     ----------   -------
worker-node-01                                         10.10.0.21       Ready      Enabled      v1.30.1
worker-node-02                                         10.10.0.22       Ready      Enabled      v1.30.1
worker-node-03                                         10.10.0.23       NotReady   Disabled     v1.30.1
```

단, Bash completion의 구조상 실제 입력되는 completion value는 `node name`만 사용한다.

즉 화면에는 다음처럼 보이고:

```text
worker-node-01    10.10.0.21
```

명령줄에는 다음 값이 들어간다.

```bash
k8s-do dev-workload worker-node-01
```

IP로 직접 입력하는 것은 계속 지원한다.

```bash
k8s-do dev-workload 10.10.0.21
```

이 방식이 좋은 이유:

- IP만 먼저 나열되는 문제를 제거한다.
- 사람이 실제로 선택하는 기준인 Node 이름을 우선 보여준다.
- IP 정보는 같은 라인에 같이 보이므로 운영자가 노드를 구분하기 쉽다.
- InternalIP가 없는 노드는 `-`를 IP 자동완성 후보로 노출하지 않는다.

---

## 7. Private key 자동 매핑

static 모드에서는 cluster 이름 기준으로 private key를 자동 탐색한다.

예를 들어 cluster 이름이 `prod-workload`이면 다음 순서로 key를 찾는다.

```text
/srv/k8s/file/ssh/privatekey/prod-workload
/srv/k8s/file/ssh/privatekey/prod-workload.pem
/srv/k8s/file/ssh/privatekey/prod-workload.key
```

따라서 운영에서는 다음 규칙을 권장한다.

```text
kubeconfigs/prod-workload.conf
privatekey/prod-workload.pem
```

---

## 8. 설치 예시

번들 압축 해제:

```bash
tar -xzf k8s-do-v3.2-bundle.tar.gz
cd k8s-do-v3.2-bundle
```

설치:

```bash
sudo install -d -m 750 /etc/k8s-do

sudo install -m 755 k8s-do /usr/local/bin/k8s-do
sudo install -m 644 k8s-do.completion /etc/bash_completion.d/k8s-do
sudo install -m 640 config.sh /etc/k8s-do/config.sh
```

설정 파일 수정:

```bash
sudo vi /etc/k8s-do/config.sh
```

확인:

```bash
k8s-do version
k8s-do list
k8s-do nodes dev-workload
```

현재 shell에 completion 반영:

```bash
source /etc/bash_completion.d/k8s-do
```

---

## 9. 필요 권한 및 사전 조건

로컬 실행 환경에 필요한 것:

```text
bash
kubectl
ssh
base64
```

Egress check에서 있으면 좋은 것:

```text
tcpdump
conntrack
ip
arping 또는 arping 대체 명령
```

Kubernetes 권한:

- nodes 조회 권한
- pods 조회 권한
- events 조회 권한
- fix-tool Pod에 exec 가능한 권한

노드 SSH 권한:

- `K8S_DO_USER` 계정으로 접속 가능해야 한다.
- private key 권한은 `600` 권장이다.

```bash
chmod 600 /srv/k8s/file/ssh/privatekey/*.pem
```

---

## 10. 테스트 결과

mock `kubectl`과 mock `ssh`를 사용해 CLI 로직을 검증했다.

검증 항목:

```text
[PASS] /srv/k8s path is configured in config.sh
[PASS] static kubeconfig directory discovery
[PASS] cluster-name completion
[PASS] node completion table displays NODE and INTERNAL-IP per row
[PASS] bash completion inserts node names only
[PASS] direct node IP input is still supported
[PASS] private-key filename mapping
[PASS] selected node resolves to the expected SSH IP
[PASS] bash completion wrapper
```

주의할 점은 이 테스트가 실제 운영 Kubernetes API에 붙은 E2E 테스트는 아니라는 점이다. 실제 운영에서는 아래 명령으로 kubeconfig, RBAC, SSH 경로까지 확인해야 한다.

```bash
k8s-do list
k8s-do nodes <cluster>
k8s-do check <cluster> <node-name>
k8s-do exec <cluster> <node-name> -- 'hostname'
```

---

## 11. 현재 v3.1 기준 한계 및 개선 후보

### 11.1 Bash completion 표시 제약

Bash는 zsh/fish처럼 completion candidate에 별도 description column을 자연스럽게 붙이는 기능이 제한적이다. 그래서 현재 구현은 다음 방식이다.

- 실제 자동완성 입력값: node name
- 사람이 보는 목록: node name + InternalIP table
- IP 직접 입력: 계속 지원

zsh/fish까지 지원하면 `node-name:10.10.0.21` 형태의 description completion을 더 깔끔하게 구현할 수 있다.

### 11.2 Egress check는 fix-tool Pod 전제

기본적으로 `fix-tool` Namespace와 `fix-tool` prefix의 Running Pod를 찾는다.

운영 환경에서 debug Pod 이름이 다르면 다음 옵션을 사용해야 한다.

```bash
--namespace <ns>
--pod-prefix <prefix>
--pod <name>
```

### 11.3 노드 SSH 계정은 단일 기본값

기본 SSH 계정은 다음과 같다.

```bash
K8S_DO_USER="vmware-system-user"
```

클러스터별로 SSH 계정이 다르면 추후 cluster별 user mapping 기능을 추가하는 것이 좋다.

### 11.4 kubeconfig 파일명 규칙 의존

static 모드는 파일명 stem을 cluster 이름으로 사용한다.

예:

```text
dev-workload.conf -> dev-workload
```

이는 운영자가 직관적으로 관리하기 좋지만, 파일명 규칙이 깨지면 CLI에서 보이는 이름도 달라진다. 따라서 kubeconfig 파일명은 cluster 이름과 맞추는 것을 권장한다.

---

## 12. 추천 명령어 체계

현재 이미 `k8s-check`를 `/usr/local/bin/k8s-check`로 등록해 사용하고 있다면, 다음처럼 맞추는 것이 좋다.

```text
k8s-check   # 전체 클러스터 점검
k8s-do      # 노드 SSH, exec, doctor, egress-check 등 운영 작업 수행
```

추후 기능이 늘어나면 다음 구조도 가능하다.

```text
k8s-check       # 정기/일괄 점검
k8s-do          # 수동 운영 액션
k8s-do nodes    # 노드 조회
k8s-do check    # SSH reachability 확인
k8s-do exec     # 원격 명령 실행
k8s-do doctor   # 노드 진단 수집
k8s-do egress-check # Egress 통신 검증
```

`k8s-do`는 짧고, 기억하기 쉽고, `ssh`에 한정되지 않는다. 현재 기능 범위에는 가장 자연스러운 이름이다.

