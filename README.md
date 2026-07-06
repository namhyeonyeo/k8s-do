# cluster-ssh

VMware Tanzu / vSphere Kubernetes Service(VKS) Workload Cluster 노드에
빠르게 SSH 접속하고 상태를 확인하기 위한 Bash CLI.

여러 클러스터의 kubeconfig와 SSH private key 경로를 외우고, 노드 IP를
`kubectl get nodes -o wide`로 매번 찾아 복사하는 작업을 없애는 것이 목적이다.

## 기능 (v2.0.0)

- `cluster-ssh <cluster>` 실행 시 노드 목록을 출력하고 대화형으로 선택
- 노드 이름 / IP / 목록 INDEX 중 무엇으로도 접속 가능
- Bash completion이 클러스터명과 노드명을 자동완성
  (completion이 조회 로직을 복제하지 않고 `cluster-ssh __complete`를 호출)
- Discovery 모드 3종: `static` / `supervisor` / `hybrid`
- 진단 명령: `doctor`, `check`, `exec`, `egress-check`
- Supervisor 모드에서 SSH private key는 실행 중 임시 디렉터리에만 존재하고 종료 시 삭제
- 노드/클러스터 조회 캐시로 Tab completion 지연 완화

## 구성

```text
bin/cluster-ssh                   실행 파일
completion/cluster-ssh.completion Bash completion
config/config.sh                  환경별 설정 (클러스터 매핑, 경로)
docs/INSTALL.md                   설치 및 운영 가이드
```

## 빠른 시작

```bash
sudo install -m 755 bin/cluster-ssh /usr/local/bin/cluster-ssh
sudo install -d -m 750 /etc/cluster-ssh
sudo install -m 640 config/config.sh /etc/cluster-ssh/config.sh
sudo install -m 644 completion/cluster-ssh.completion /etc/bash_completion.d/cluster-ssh
source /etc/bash_completion.d/cluster-ssh

cluster-ssh list
cluster-ssh nodes dev-workload
cluster-ssh dev-workload
```

자세한 내용은 [docs/INSTALL.md](docs/INSTALL.md) 참고.
