# cluster-ssh v2 설치 및 운영 가이드

## 1. 주요 변경점

- `cluster-ssh <cluster>` 실행 시 노드 이름과 IP 목록을 출력하고 대화형으로 선택
- 노드 이름, IP, 목록의 INDEX 모두 접속 대상으로 사용 가능
- Bash completion이 IP뿐 아니라 노드 이름도 자동완성
- completion 파일이 Kubernetes 조회 로직을 복제하지 않고 `cluster-ssh __complete`를 호출
- Static / Supervisor API / Hybrid discovery 지원
- `doctor`, `exec`, `egress-check` 진단 명령 추가
- Supervisor API 모드에서 kubeconfig는 보안 캐시에 저장하고 SSH private key는 실행 중 임시 디렉터리에만 생성 후 삭제
- 노드/API 조회 캐시로 Tab completion 지연 완화

## 2. 설치

```bash
sudo mkdir -p /etc/cluster-ssh
sudo cp cluster-ssh-v2 /usr/local/bin/cluster-ssh
sudo cp config-v2.sh /etc/cluster-ssh/config.sh
sudo cp cluster-ssh-v2.completion /etc/bash_completion.d/cluster-ssh

sudo chmod 755 /usr/local/bin/cluster-ssh
sudo chmod 640 /etc/cluster-ssh/config.sh
sudo chmod 644 /etc/bash_completion.d/cluster-ssh
```

Config를 여러 사용자가 공용으로 읽어야 하는 환경에서는 그룹을 지정합니다.

```bash
sudo chown root:k8s-ops /etc/cluster-ssh/config.sh
sudo chmod 640 /etc/cluster-ssh/config.sh
```

Completion 반영:

```bash
source /etc/bash_completion
source /etc/bash_completion.d/cluster-ssh
```

## 3. Static 모드

```bash
CLUSTER_DISCOVERY_MODE="static"
```

기존처럼 `CLUSTERS`, `get_cluster_kubeconfig()`, `get_cluster_private_key()`를 사용합니다.

```bash
cluster-ssh list
cluster-ssh nodes dev-workload
cluster-ssh dev-workload
cluster-ssh dev-workload <node-name>
cluster-ssh dev-workload <node-ip>
cluster-ssh dev-workload 2
```

## 4. Supervisor API 모드

```bash
CLUSTER_DISCOVERY_MODE="supervisor"
SUPERVISOR_KUBECONFIG="/secure/path/supervisor-kubeconfig"
```

필요한 권한:

```text
clusters.cluster.x-k8s.io: get, list
secrets/<cluster-name>-kubeconfig: get
secrets/<cluster-name>-ssh: get
```

동작 흐름:

```text
Supervisor API
  ├─ Cluster API 객체 조회: namespace/cluster-name
  ├─ <cluster-name>-kubeconfig Secret의 data.value 추출
  ├─ Workload Cluster API에서 Node 이름/InternalIP 조회
  └─ SSH 직전에 <cluster-name>-ssh Secret의 data.ssh-privatekey 추출
```

테스트:

```bash
cluster-ssh refresh
cluster-ssh list
cluster-ssh nodes <namespace>/<cluster-name>
cluster-ssh <namespace>/<cluster-name>
```

짧은 별칭 사용:

```bash
declare -A CLUSTER_ALIASES=(
  [dev-workload]="dev-ns/tkg-example-dev-workload-cluster-001"
)
```

## 5. Hybrid 모드

```bash
CLUSTER_DISCOVERY_MODE="hybrid"
```

Static mapping을 우선 사용하고, Static에 없는 이름은 Supervisor API에서 조회합니다.

## 6. 노드 선택 UX

`cluster-ssh dev-workload`를 실행하면 다음과 같이 표시됩니다.

```text
INDEX NODE                                                   INTERNAL-IP      STATUS     SCHEDULING   VERSION
1     tkg-dev-control-plane-xxxxx                            10.10.10.11      Ready      Enabled      v1.30.1
2     tkg-dev-md-0-xxxxx                                     10.10.10.21      Ready      Enabled      v1.30.1
3     tkg-dev-md-0-yyyyy                                     10.10.10.22      Ready      Enabled      v1.30.1
```

`fzf`가 설치되어 있으면 검색형 선택 화면을 사용하고, 없으면 INDEX/노드 이름/IP를 입력합니다.

## 7. 트러블슈팅 명령

### 노드 기본 진단

```bash
cluster-ssh doctor dev-workload <node-name>
```

수집 항목:

- Kubernetes Node describe
- 해당 노드에 배치된 Pod
- Node 이벤트
- 주소, 라우팅, neighbor table
- 파일시스템, inode, 메모리, PSI
- kubelet/containerd 상태
- 최근 kubelet warning 로그
- crictl 상태
- kernel warning

출력 파일 지정:

```bash
cluster-ssh doctor dev-workload <node-name> --output /tmp/node-doctor.log
```

### 원격 읽기 명령

```bash
cluster-ssh exec dev-workload <node-name> -- \
  'sudo journalctl -u kubelet --since "-20 min" --no-pager'
```

### Egress IP 충돌 확인

```bash
cluster-ssh egress-check dev-workload <egress-node> \
  --egress-ip 10.60.93.191 \
  --dst 10.60.191.31 \
  --port 8522
```

주의: ARP 결과는 동일 L2 구간에서 가장 유효합니다. Overlay, proxy ARP, 라우터 경유, 보안장비 필터링 환경에서는 ARP 무응답만으로 미사용 IP라고 단정하면 안 됩니다.

## 8. 캐시

기본 위치:

```text
~/.cache/cluster-ssh/
```

캐시 삭제:

```bash
cluster-ssh refresh
cluster-ssh refresh dev-workload
```

## 9. 보안 권고

- Supervisor kubeconfig에는 최소 권한만 부여
- 가능하면 Secret 전체 `get` 권한 대신 대상 namespace와 이름을 제한한 Role 사용
- Private key는 공용 디렉터리에 영구 저장하지 않음
- `StrictHostKeyChecking=no`를 사용하지 않음
- cluster-ssh 전용 known_hosts 파일을 사용
- `exec`는 감사 로그 대상이며, 운영 정책상 필요하면 허용 명령 allowlist 방식으로 제한
- 진단 기본값은 읽기 전용으로 유지하고 drain/restart/delete 같은 변경 작업은 별도 승인 명령으로 분리

## 10. 검증

```bash
bash -n /usr/local/bin/cluster-ssh
cluster-ssh version
cluster-ssh list
cluster-ssh nodes dev-workload
cluster-ssh check dev-workload <node-name>
```
