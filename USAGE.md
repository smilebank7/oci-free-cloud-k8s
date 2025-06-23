# OCI 무료 티어 쿠버네티스 클러스터 - 사용 가이드

이 가이드는 Oracle Cloud Infrastructure (OCI)의 Always Free 티어 리소스를 사용하여 쿠버네티스 클러스터를 배포하는 단계별 지침을 제공합니다.

## 사전 요구사항

### 1. OCI 계정 설정
- Always Free 티어 자격이 있는 Oracle Cloud 계정 생성
- 컴파트먼트에서 리소스를 생성할 수 있는 권한 확인
- 컴파트먼트 OCID 메모 (설정에 필요)

### 2. 로컬 환경 설정
다음 도구들을 설치하세요:
- **Terraform** (v1.6+): [다운로드](https://www.terraform.io/downloads)
- **OCI CLI**: [설치 가이드](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- **kubectl**: [설치 가이드](https://kubernetes.io/docs/tasks/tools/)

### 3. OCI CLI 구성
```bash
# 구성 마법사 실행
oci setup config

# ~/.oci/config 파일이 생성되며 다음 정보가 필요합니다:
# - User OCID
# - Tenancy OCID  
# - Region
# - Private key 경로
```

### 4. Terraform 상태 저장용 S3 호환 버킷 생성
```bash
# <compartment-id>를 실제 컴파트먼트 OCID로 변경
oci os bucket create --name terraform-states --versioning Enabled --compartment-id <compartment-id>
```

## 배포 단계

### 1단계: 저장소 클론
```bash
git clone <your-repo-url>
cd oci-free-cloud-k8s/terraform/infra
```

### 2단계: Terraform 변수 구성
```bash
# 예제 파일 복사
cp terraform.tfvars.example terraform.tfvars

# 값 편집
vim terraform.tfvars
```

필수 설정 변수:
- `compartment_id`: OCI 컴파트먼트 OCID
- `ssh_public_key`: 노드 접근용 SSH 공개 키

선택적 변수:
- `region`: OCI 리전 (기본값: eu-frankfurt-1)
- `kubernetes_version`: K8s 버전 (기본값: v1.32.1)
- 리소스 이름들 (기본적으로 모두 s6g 접두사 포함)

### 3단계: Terraform 초기화
```bash
terraform init
```

이 명령은:
- 필요한 프로바이더 다운로드
- 상태 저장을 위한 S3 백엔드 구성
- 작업 디렉토리 준비

### 4단계: 플랜 검토
```bash
terraform plan
```

생성될 리소스 검토:
- 퍼블릭/프라이빗 서브넷이 있는 VCN
- 인터넷 게이트웨이, NAT 게이트웨이, 서비스 게이트웨이
- 네트워크 접근을 위한 보안 목록
- OKE 클러스터 (컨트롤 플레인)
- ARM 기반 워커 노드 2개를 가진 노드 풀
- 로드 밸런서 서브넷 구성

### 5단계: 인프라 배포
```bash
terraform apply
```

프롬프트가 나타나면 `yes`를 입력하세요. 완료까지 약 10-15분이 소요됩니다.

### 6단계: 클러스터 접근
배포 후 kubeconfig 파일이 자동으로 생성됩니다:

```bash
# kubeconfig가 상위 디렉토리에 저장됩니다
export KUBECONFIG=$(pwd)/../.kube.config

# 클러스터 접근 확인
kubectl get nodes
kubectl get pods -A
```

## 배포 후 구성

### 1. FluxCD 배포 (GitOps)
GitOps 배포를 위해 FluxCD를 사용하려는 경우:

1. 다음 권한을 가진 GitHub Personal Access Token 생성:
   - Contents: read, write
   - Commit statuses: read, write  
   - Webhooks: read, write

2. OCI Vault에 `github-fluxcd-token`으로 토큰 저장

3. `terraform/config` 디렉토리에서 FluxCD 구성 (사용 가능한 경우)

### 2. 필수 컴포넌트 설치
클러스터가 워크로드 배포 준비가 완료되었습니다. 다음 설치를 고려하세요:
- **Ingress Controller**: NGINX ingress 권장
- **스토리지**: 영구 볼륨용 Longhorn
- **Cert-Manager**: TLS 인증서용
- **External-DNS**: 자동 DNS 관리용

### 3. Teleport 구성 (선택사항)
Teleport를 통한 안전한 클러스터 접근:
- Helm 차트를 사용하여 Teleport 배포
- 인증을 위한 GitHub SSO 구성
- 적절한 RBAC 매핑 설정

## 유지보수 작업

### 쿠버네티스 버전 업그레이드
```bash
# 사용 가능한 버전 확인
oci ce cluster get --cluster-id $(terraform output --raw k8s_cluster_id) | jq -r '.data."available-kubernetes-upgrades"'

# terraform.tfvars에서 버전 업데이트
# kubernetes_version = "v1.32.2"

# 변경사항 적용
terraform apply
```

### 워커 노드 스케일링
```bash
# terraform.tfvars 편집
# kubernetes_worker_nodes = 3  # 최대값은 무료 티어 한도에 따름

terraform apply
```

## 리소스 제한 (OCI Always Free 티어)

클러스터는 Always Free 티어 제한에 따라 제약됩니다:
- **컴퓨팅**: 총 4 OCPU 및 24GB 메모리
- **스토리지**: 총 200GB 블록 볼륨 스토리지
- **로드 밸런서**: 1개의 플렉시블 LB (10 Mbps)
- **아키텍처**: ARM 기반 인스턴스만 가능 (VM.Standard.A1.Flex)

현재 구성 사용량:
- 2개 워커 노드 × 2 OCPU × 12GB RAM = 4 OCPU, 24GB RAM
- 2개 워커 노드 × 100GB 부트 볼륨 = 200GB 스토리지

## 문제 해결

### Terraform 상태 문제
S3 백엔드 오류가 발생하는 경우:
```bash
# OCI CLI가 올바르게 구성되었는지 확인
oci iam user get --user-id <your-user-ocid>

# 버킷 접근 확인
oci os bucket get --name terraform-states
```

### Node Not Ready
노드가 NotReady로 표시되는 경우:
```bash
# 노드 로그 확인
kubectl describe node <node-name>

# 노드에 SSH 접속 (프라이빗 키 사용)
ssh -i <private-key-path> opc@<node-ip>
```

### 리소스 부족
용량 부족으로 배포가 실패하는 경우:
- 다른 가용성 도메인 시도
- 노드 수 또는 크기 축소
- 테넌시 한도 확인

## 정리

모든 리소스를 삭제하려면:
```bash
terraform destroy
```

**경고**: 이 명령은 배포된 워크로드와 영구 데이터를 포함한 모든 클러스터 리소스를 삭제합니다.

## 추가 리소스

- [OCI Always Free 티어 세부정보](https://www.oracle.com/cloud/free/)
- [OKE 문서](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
- [원본 저장소 README](../../README.md) - 아키텍처 세부정보