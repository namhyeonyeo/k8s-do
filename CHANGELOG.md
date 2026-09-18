# Changelog

`cluster-ssh`에서 시작해 `k8s-do`가 되기까지의 변경 내역.
모든 버전은 실제 운영 중에 나온 요구나 장애 분석 과정에서 추가된 것이다.

## v3.2.5 - 2026-09-18

- `k8s-do ssh <cluster> <node>` 명시적 SSH 서브커맨드 추가 (기존 `k8s-do <cluster> <node>` 호환 유지)
- Tab completion이 노드 테이블을 출력하던 문제 제거.
  completion은 `__complete node-values`만 사용하고 기존 노드 캐시만 읽는다.
  → Tab 입력 중 kubectl auth plugin / SSO / 사번 프롬프트가 뜨던 문제 해결
- `doctor`의 `--output` 생략 시 현재 디렉터리를 더럽히지 않고 `/tmp/k8s-do-doctor`에 저장
- `doctor` 상단에 Quick Diagnosis Summary(Node Ready, Scheduling, 문제 Pod 수, Warning Event 수) 추가
- `egress-check` 기본 출력을 요약 중심으로 변경. tcpdump/conntrack 원문은 파일에만 저장하고
  터미널 출력은 `--verbose`로 분리. 기본 저장 위치 `/tmp/k8s-do-egress`
- ARP 중복 검사를 일반 arping에서 DAD 방식(`arping -D -I <iface> -c 5 -w 5`)으로 변경
- `owner_interface` / `route_interface` / `capture_interface` / `arp_interface` 역할 분리 출력
- `tests/test-egress-arp-logic.sh` 추가

## v3.2.2 - 2026-09-15

- kubeconfig 파일명 suffix 자동 처리
  (`-kubeconfig`, `.conf`, `.kubeconfig`, `.yaml` → 클러스터명)
- private key 파일명 자동 인식
  (`<cluster>`, `.pem`, `.key`, `-ssh-privatekey`, `-ssh` 및 조합)
- `k8s-do nodes`(사람용 표)와 `__complete nodes`(노드명만) 출력 분리.
  completion 후보에 `INDEX`, `NODE`, `Ready` 같은 헤더 문자열이 섞이던 문제 해결
- 사람이 보는 노드 표를 위한 `__complete node-table` helper 추가
- `install.sh` 설치 스크립트 추가 (기존 config는 타임스탬프 백업 후 교체)
- `tests/test-kubeconfig-suffix.sh`, `tests/test-k8s-do-v3.2.2.sh` 추가

## v3.2 - 2026-09-10

- **`cluster-ssh` → `k8s-do` 개명.** 도구가 SSH 접속 전용이 아니라 진단/원격 실행/
  Egress 검증까지 포함하게 되어 이름과 설정 네임스페이스를 통일
- 설정 경로 `/etc/cluster-ssh` → `/etc/k8s-do`, 환경 변수 `CLUSTER_SSH_*` → `K8S_DO_*`
- 기본 static 경로를 `/srv/tanzu` → `/srv/k8s` 계열로 이전
- 전체 기능 정리 문서(`docs/feature-guide.md`) 추가
- `tests/test-k8s-do-v3.2.sh` 검증 스크립트 추가

## v3.0.0 - 2026-09-07

`egress-check`를 실제 장애 분석에 쓸 수 있는 수준으로 재작성.
Egress IP가 노드에 붙어 있는지만 보던 것에서 Pod → Egress Node → 외부 전 경로
증거 수집으로 확장했다.

- `fix-tool` Namespace의 Running 테스트 Pod 자동 탐색 (0개/2개 이상이면 실패, `--pod` 지정)
- Egress IP 로컬 소유 여부와 실제 외부 route interface 자동 판별
- route interface에서 ARP 응답 MAC 수집으로 Egress IP 충돌 탐지
- tcpdump / conntrack 감시 중 Pod에서 TCP 연결을 발생시켜 SNAT / return traffic 판정
- Pod 내부 TCP 테스트를 `nc` → `curl telnet://` → `bash /dev/tcp` 순으로 fallback
- 판정 결과를 exit code 0/1/2/3으로 분리
- completion이 `_init_completion`에 의존하지 않도록 수정
- 모든 동작을 읽기 전용으로 제한 (IP 해제, conntrack flush, iptables 변경 없음)

## v2.0.0 - 2026-07-06

- `cluster-ssh <cluster>` 실행 시 노드 목록 출력 후 대화형 선택
- 노드 이름 / InternalIP / 목록 INDEX 중 무엇으로도 접속
- Bash completion이 조회 로직을 복제하지 않고 `cluster-ssh __complete` 호출
- Discovery 모드 3종: `static` / `supervisor` / `hybrid`
- `doctor`, `check`, `exec`, `egress-check` 진단 명령 추가
- Supervisor 모드에서 kubeconfig는 보안 캐시, private key는 실행 중 임시 디렉터리에만 생성
- 노드 / API 조회 캐시로 Tab completion 지연 완화
