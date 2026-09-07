# cluster-ssh

VMware Tanzu / vSphere Kubernetes Service(VKS) Workload Cluster 노드에
빠르게 SSH 접속하고, 노드와 Egress 통신을 진단하기 위한 Bash CLI.

## 기능

### v2.0.0

- 노드 목록 출력 후 대화형 선택 (이름 / IP / INDEX)
- Bash completion이 `cluster-ssh __complete`를 호출해 조회 로직 중복 제거
- Discovery 모드 3종: `static` / `supervisor` / `hybrid`
- `doctor`, `check`, `exec` 진단 명령
- 노드/클러스터 조회 캐시

### v3.0.0

`egress-check`를 실제 운영 장애 분석에 쓸 수 있는 수준으로 재작성했다.
Egress IP가 "노드에 붙어 있는지"만 보던 것에서, **Pod → Egress Node → 외부**
경로 전체를 한 명령으로 증거 수집하도록 바꿨다.

한 번의 `egress-check`가 수행하는 작업:

1. 클러스터 kubeconfig 해석
2. `fix-tool` Namespace에서 Running 테스트 Pod 자동 탐색
3. Pod 이름 / Pod IP / 배치된 Node 조회
4. 지정한 Egress Node에 SSH 연결
5. Egress IP의 로컬 소유 여부, 실제 외부 route interface 확인
6. route interface에서 ARP 응답 MAC 수집 (IP 충돌 탐지)
7. Egress Node에서 tcpdump / conntrack 감시 시작
8. Pod 내부에서 목적지 TCP 연결 실행
9. Pod 트래픽 / Egress IP SNAT / return traffic 증거 판정
10. 전체 결과를 로그 파일로 저장

읽기 전용이다. Egress IP 해제, conntrack 삭제, iptables 변경,
cordon/drain, service restart는 하지 않는다.

Exit code로 판정 결과를 구분한다.

| Code | 의미 |
|---:|---|
| 0 | Egress IP 존재, Pod 테스트 성공, SNAT 증거 확인 |
| 1 | 입력/설정/Pod 탐색/SSH/capture 준비 오류 |
| 2 | Pod 연결 실패, Egress IP 미소유 또는 SNAT 증거 미확인 |
| 3 | 복수 ARP MAC 감지 (IP 충돌 의심) |

## 구성

```text
bin/cluster-ssh                   실행 파일
completion/cluster-ssh.completion Bash completion
config/config.sh                  환경별 설정 (클러스터 매핑, 경로, fix-tool Pod)
docs/INSTALL.md                   설치 및 Egress 진단 Runbook
```

## 사용 예

```bash
cluster-ssh list
cluster-ssh nodes dev-workload
cluster-ssh dev-workload worker-node-01
cluster-ssh exec dev-workload worker-node-01 -- 'sudo journalctl -u kubelet -n 100 --no-pager'
cluster-ssh doctor dev-workload worker-node-01
cluster-ssh egress-check dev-workload worker-node-01 \
  --egress-ip 10.60.196.92 --dst 10.60.196.60 --port 22
```

설치와 결과 해석은 [docs/INSTALL.md](docs/INSTALL.md) 참고.
