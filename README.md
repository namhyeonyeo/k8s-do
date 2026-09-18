# k8s-do

VMware Tanzu / vSphere Kubernetes Service(VKS) Workload Cluster 운영용 Bash CLI.
**노드 SSH 접속, 노드 진단, 원격 명령 실행, Egress 통신 검증**을 하나의 명령 체계로 묶었다.

여러 클러스터의 kubeconfig / private key 경로를 외우고, 노드 IP를 매번
`kubectl get nodes -o wide`에서 찾아 복사하던 작업을 없애는 것에서 시작해,
운영 중 실제로 필요했던 진단 기능을 하나씩 붙여 온 도구다.
그래서 이름도 `cluster-ssh`에서 `k8s-do`로 바뀌었다.

의존성은 `bash`, `kubectl`, `ssh`뿐이다. (`fzf`, `arping`, `tcpdump`, `conntrack`은 있으면 사용)

> 문서와 설정에 나오는 클러스터명, IP, 파일 경로는 모두 예시 값으로 바꿔 둔 것이다.
> 실제 운영 환경의 값이 아니다.

## 명령

```text
k8s-do list                                        클러스터 목록
k8s-do nodes <cluster>                             노드 표 출력 + 노드 캐시 갱신
k8s-do <cluster>                                   노드 목록에서 대화형 선택 후 SSH
k8s-do <cluster> <node|ip|index>                   바로 SSH
k8s-do ssh <cluster> <node|ip|index>               명시적 SSH
k8s-do check <cluster> <node>                      접속/기본 상태 확인
k8s-do exec <cluster> <node> -- '<command>'        원격 명령 실행 (읽기 전용 용도)
k8s-do doctor <cluster> <node> [--output <file>]   노드 종합 진단
k8s-do egress-check <cluster> <egress-node> \      Egress 통신 증거 수집
    --egress-ip <ip> --dst <ip> --port <port> [--verbose]
k8s-do refresh [cluster]                           캐시 초기화
k8s-do version
```

클러스터 지정 형식:

```text
static mode     : dev-workload
supervisor mode : <namespace>/<cluster-name>
alias           : dev-workload -> <namespace>/<cluster-name>
```

## 주요 기능

### 노드 접근

노드 이름 / InternalIP / 목록 INDEX 중 무엇으로도 접속한다.
`fzf`가 설치되어 있으면 검색형 선택 화면을 쓰고, 없으면 번호를 입력한다.

```text
INDEX NODE                                     INTERNAL-IP    STATUS  SCHEDULING  VERSION
1     tkg-example-prd-...-md-0-a1b2c-d3e4f-k6ncv  10.50.93.46    Ready   Enabled     v1.33.1+vmware.1-fips
2     tkg-example-prd-...-md-0-a1b2c-d3e4f-psqfs  10.50.93.47    Ready   Enabled     v1.33.1+vmware.1-fips
```

### Discovery 모드

| 모드 | 동작 |
|---|---|
| `static` | config의 파일 경로 매핑에서 kubeconfig / private key를 찾는다 |
| `supervisor` | Supervisor API에서 Cluster API 객체와 `-kubeconfig` / `-ssh` Secret을 조회한다 |
| `hybrid` | static을 우선 사용하고, 없으면 Supervisor API로 조회한다 |

Supervisor 모드에서 SSH private key는 **SSH 직전에** Secret에서 꺼내
실행 중 임시 디렉터리에만 생성하고 종료 시 삭제한다.

### doctor

노드 한 대의 상태를 한 번에 수집하고 상단에 Quick Diagnosis Summary
(Node Ready, Scheduling, 문제 Pod 수, Warning Event 수)를 먼저 보여준다.

수집 항목: Node describe / 배치된 Pod / Node 이벤트 / 주소·라우팅·neighbor table /
파일시스템·inode·메모리·PSI / kubelet·containerd 상태 / kubelet warning 로그 /
crictl 상태 / kernel warning.

### egress-check

Antrea Egress 환경에서 "Egress IP로 나가야 할 트래픽이 실제로 그렇게 나가는가"를
추측이 아니라 패킷 증거로 판정한다.

1. 클러스터 kubeconfig 해석
2. `fix-tool` Namespace의 Running 테스트 Pod 자동 탐색 (2개 이상이면 실패, `--pod`로 지정)
3. Egress Node에 SSH 접속해 Egress IP 소유 인터페이스와 실제 route interface 확인
4. `arping -D`(DAD)로 Egress IP 중복 응답 MAC 검사
5. tcpdump / conntrack 감시 시작
6. Pod 내부에서 목적지로 TCP 연결 발생 (`nc` → `curl telnet://` → `bash /dev/tcp` 순)
7. Pod 트래픽 / Egress IP SNAT / return traffic 관측 여부로 PASS·WARN·FAIL 판정

인터페이스 의미를 분리해서 출력한다.

| 항목 | 의미 |
|---|---|
| `owner_interface` | Egress IP가 할당된 인터페이스 (보통 `antrea-egress0`) |
| `route_interface` | 목적지로 갈 때 커널이 고른 인터페이스 (보통 `eth0`) |
| `capture_interface` | tcpdump 대상. 기본 `route_interface`, `--iface`로 override |
| `arp_interface` | 중복 IP 검사용 L2 인터페이스 |

Exit code:

| Code | 의미 |
|---:|---|
| 0 | Egress IP 존재, Pod 테스트 성공, SNAT 증거 확인 |
| 1 | 입력 / 설정 / Pod 탐색 / SSH / capture 준비 오류 |
| 2 | Pod 연결 실패, Egress IP 미소유 또는 SNAT 증거 미확인 |
| 3 | ARP 응답 MAC 관측 (중복 소유 또는 proxy-ARP 가능성) |

**모든 동작은 읽기 전용이다.** Egress IP 해제, conntrack 삭제, iptables/nftables 변경,
interface 변경, cordon/drain, service restart는 하지 않는다.

ARP 결과는 동일 L2 구간에서만 유효하다. overlay / proxy ARP / 라우터 경유 환경에서는
보조 증거로만 쓴다.

### 보안

- private key를 공용 디렉터리에 영구 저장하지 않는다
- `StrictHostKeyChecking=no`를 쓰지 않고, 전용 known_hosts 파일을 사용한다
- Supervisor kubeconfig에는 최소 권한만 부여한다 (`clusters.cluster.x-k8s.io` get/list, 해당 Secret get)
- 진단 기본값은 읽기 전용. drain / restart / delete 같은 변경 작업은 포함하지 않는다

## 구성

```text
bin/k8s-do                    실행 파일 (Bash, 단일 스크립트)
completion/k8s-do.completion  Bash completion
config/config.sh              클러스터 매핑, 경로, fix-tool Pod 설정
install.sh                    설치 스크립트 (기존 config 백업 후 교체)
docs/INSTALL.md               설치 및 Egress 진단 Runbook
docs/feature-guide.md         전체 기능 정리 및 사용법
docs/egress-runbook.md        Egress 진단 결과 해석 Runbook
docs/releases/                버전별 변경 내역
tests/                        동작 검증 스크립트
```

## 설치

```bash
sudo ./install.sh
complete -r k8s-do 2>/dev/null
source /etc/bash_completion.d/k8s-do
hash -r
```

확인:

```bash
k8s-do version
k8s-do list
k8s-do nodes <cluster>
k8s-do __complete node-values <cluster>   # 노드명만 출력되어야 정상
```

## 버전 기록

| 버전 | 날짜 | 내용 |
|---|---|---|
| v2.0.0 | 2026-07-06 | 노드 선택 UX, completion 위임, static/supervisor/hybrid discovery, doctor/exec 추가 |
| v3.0.0 | 2026-09-07 | egress-check를 Pod→Node→외부 전 경로 증거 수집으로 재작성, exit code 판정 |
| v3.2   | 2026-09-10 | `cluster-ssh` → `k8s-do` 개명, 기본 경로 `/srv/k8s` 이전 |
| v3.2.2 | 2026-09-15 | 운영 파일명 suffix 자동 인식, completion 출력 분리, 설치 스크립트 |
| v3.2.5 | 2026-09-18 | `ssh` 서브커맨드, completion 부작용 제거, ARP DAD 검사, 출력 요약화 |

상세 내역은 [CHANGELOG.md](CHANGELOG.md) 참고.

## 테스트

```bash
bash -n bin/k8s-do
for t in tests/*.sh; do bash "$t"; done
```

## 진행 중

실 운영에 쓰면서 계속 수정하고 있다. 현재 보고 있는 항목:

- doctor 결과의 자동 판정 항목 확대
- egress-check의 CNI dataplane별 판정 분기 (Antrea 외 환경)
- supervisor 모드에서 Secret 접근 권한을 namespace/name 단위로 좁히는 Role 예시 정리
