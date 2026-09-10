# k8s-do

VMware Tanzu / vSphere Kubernetes Service(VKS) Workload Cluster 운영용 Bash CLI.
노드 SSH 접속, 노드 진단, 원격 명령 실행, Egress 통신 검증을 하나의 명령 체계로 묶었다.

`cluster-ssh`로 시작했지만 기능이 SSH 접속을 넘어섰기 때문에 v3.2에서 `k8s-do`로 이름을 바꿨다.

## 명령

```text
k8s-do list
k8s-do nodes <cluster>
k8s-do <cluster>                       노드 목록에서 대화형 선택 후 SSH
k8s-do <cluster> <node|ip|index>
k8s-do check <cluster> <node>
k8s-do exec <cluster> <node> -- '<remote command>'
k8s-do doctor <cluster> <node> [--output <file>]
k8s-do egress-check <cluster> <egress-node> --egress-ip <ip> --dst <ip> --port <port>
k8s-do refresh [cluster]
k8s-do version
```

## 기능

- **노드 접근**: 이름 / IP / 목록 INDEX 중 무엇으로도 접속. `fzf`가 있으면 검색형 선택.
- **Discovery**: `static`(파일 경로 매핑) / `supervisor`(Cluster API + Secret 조회) / `hybrid`
- **doctor**: Node describe, 배치 Pod, 이벤트, 라우팅/neighbor, 파일시스템·inode·메모리·PSI,
  kubelet/containerd 상태, kubelet warning, crictl, kernel warning을 한 번에 수집
- **egress-check**: Pod → Egress Node → 외부 경로를 tcpdump/conntrack 증거로 판정 (읽기 전용)
- **보안**: private key는 실행 중 임시 디렉터리에만 존재, 전용 known_hosts 사용,
  `StrictHostKeyChecking=no` 미사용

## 구성

```text
bin/k8s-do                    실행 파일
completion/k8s-do.completion  Bash completion
config/config.sh              클러스터 매핑, 경로, fix-tool Pod 설정
docs/INSTALL.md               설치 및 Egress 진단 Runbook
docs/feature-guide.md         전체 기능 정리 및 사용법
docs/egress-runbook.md        v3.1 기준 Egress 진단 Runbook
tests/                        동작 검증 스크립트
```

## 버전 기록

| 버전 | 내용 |
|---|---|
| v2.0.0 | 노드 선택 UX, completion 위임, static/supervisor/hybrid discovery |
| v3.0.0 | egress-check를 Pod→Node→외부 전 경로 증거 수집으로 재작성 |
| v3.2   | `cluster-ssh` → `k8s-do` 개명, 기본 경로 `/srv/k8s`로 이전, 검증 스크립트 추가 |

## 설치

```bash
sudo install -d -m 750 /etc/k8s-do
sudo install -m 755 bin/k8s-do /usr/local/bin/k8s-do
sudo install -m 644 completion/k8s-do.completion /etc/bash_completion.d/k8s-do
sudo install -m 640 config/config.sh /etc/k8s-do/config.sh
source /etc/bash_completion.d/k8s-do
```

자세한 내용은 [docs/INSTALL.md](docs/INSTALL.md), [docs/feature-guide.md](docs/feature-guide.md) 참고.
