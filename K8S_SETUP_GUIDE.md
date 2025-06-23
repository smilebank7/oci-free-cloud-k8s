# Kubernetes 클러스터 초기 설정 가이드

이 문서는 OCI에서 프로비저닝된 Kubernetes 클러스터에 필수 구성 요소들을 설정하는 순서와 방법을 안내합니다.

## 전체 설정 순서

1. **FluxCD 설치 및 구성** - GitOps 기반 배포 시스템
2. **Longhorn 설치** - 스토리지 프로비저너 (FluxCD를 통해)
3. **NGINX Ingress Controller 설치** - Layer 7 로드밸런서
4. **External DNS 설정** - Cloudflare DNS 자동 업데이트
5. **Cert-Manager 설치** - Let's Encrypt SSL 인증서 자동화
6. **Teleport 설치** - 클러스터 액세스 관리
7. **Dex 설치 및 OIDC 설정** - GitHub SSO 통합

## 1. FluxCD 설치 및 구성

### 1.1 사전 준비
```bash
# kubeconfig 설정
export KUBECONFIG=/path/to/.kube.config

# flux CLI 설치
curl -s https://fluxcd.io/install.sh | sudo bash

# GitHub Personal Access Token 준비
# - repo 권한 (전체)
# - workflow 권한
export GITHUB_TOKEN=<your-github-pat>
export GITHUB_USER=<your-github-username>
export GITHUB_REPO=<your-repo-name>
```

### 1.2 FluxCD Bootstrap
```bash
# FluxCD 설치 및 GitHub 저장소 연결
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/production \
  --personal
```

### 1.3 디렉터리 구조 생성
```bash
mkdir -p clusters/production/infrastructure/{controllers,configs}
mkdir -p clusters/production/apps
```

### 1.4 Kustomization 파일 생성
```yaml
# clusters/production/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-controllers
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/production/infrastructure/controllers
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-configs
  namespace: flux-system
spec:
  interval: 10m
  dependsOn:
    - name: infrastructure-controllers
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/production/infrastructure/configs
  prune: true
```

## 2. Longhorn 설치 (FluxCD를 통해)

### 2.1 Namespace 생성
```yaml
# infrastructure/controllers/longhorn-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
```

### 2.2 HelmRepository 및 HelmRelease
```yaml
# infrastructure/controllers/longhorn.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: longhorn
  namespace: flux-system
spec:
  interval: 60m
  url: https://charts.longhorn.io
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: longhorn
  namespace: longhorn-system
spec:
  interval: 30m
  chart:
    spec:
      chart: longhorn
      version: "1.6.x"
      sourceRef:
        kind: HelmRepository
        name: longhorn
        namespace: flux-system
  values:
    defaultSettings:
      defaultReplicaCount: 2
      storageMinimalAvailablePercentage: 10
    persistence:
      defaultClass: true
      defaultClassReplicaCount: 2
```

## 3. NGINX Ingress Controller 설치

### 3.1 NGINX Ingress 설정
```yaml
# infrastructure/controllers/nginx-ingress.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: ingress-nginx
  namespace: flux-system
spec:
  interval: 60m
  url: https://kubernetes.github.io/ingress-nginx
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 30m
  chart:
    spec:
      chart: ingress-nginx
      version: "4.10.x"
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: flux-system
  values:
    controller:
      service:
        type: LoadBalancer
        annotations:
          oci.oraclecloud.com/load-balancer-type: "lb"
          service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
          service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
          service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"
      metrics:
        enabled: true
```

## 4. External DNS 설정 (Cloudflare)

### 4.1 Cloudflare API Token Secret
```bash
# Cloudflare API Token 생성 후
kubectl create secret generic cloudflare-api-token \
  --from-literal=cloudflare_api_token=<your-token> \
  -n external-dns
```

### 4.2 External DNS 배포
```yaml
# infrastructure/controllers/external-dns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: external-dns
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: external-dns
  namespace: flux-system
spec:
  interval: 60m
  url: https://kubernetes-sigs.github.io/external-dns/
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: external-dns
  namespace: external-dns
spec:
  interval: 30m
  chart:
    spec:
      chart: external-dns
      version: "1.14.x"
      sourceRef:
        kind: HelmRepository
        name: external-dns
        namespace: flux-system
  values:
    provider: cloudflare
    env:
      - name: CF_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: cloudflare-api-token
            key: cloudflare_api_token
    sources:
      - ingress
      - service
    domainFilters:
      - "your-domain.com"
    policy: sync
```

## 5. Cert-Manager 설치

### 5.1 Cert-Manager 배포
```yaml
# infrastructure/controllers/cert-manager.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: jetstack
  namespace: flux-system
spec:
  interval: 60m
  url: https://charts.jetstack.io
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 30m
  chart:
    spec:
      chart: cert-manager
      version: "v1.14.x"
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: flux-system
  values:
    installCRDs: true
```

### 5.2 ClusterIssuer 설정
```yaml
# infrastructure/configs/cert-manager-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

## 6. Teleport 설치 및 구성

### 6.1 Teleport 네임스페이스 및 시크릿
```bash
# GitHub OAuth App 생성 후
kubectl create namespace teleport
kubectl create secret generic teleport-github-oauth \
  --from-literal=client-id=<github-client-id> \
  --from-literal=client-secret=<github-client-secret> \
  -n teleport
```

### 6.2 Teleport 배포
```yaml
# infrastructure/controllers/teleport.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: teleport
  namespace: flux-system
spec:
  interval: 60m
  url: https://charts.releases.teleport.dev
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: teleport-cluster
  namespace: teleport
spec:
  interval: 30m
  chart:
    spec:
      chart: teleport-cluster
      version: "15.x.x"
      sourceRef:
        kind: HelmRepository
        name: teleport
        namespace: flux-system
  values:
    clusterName: k8s.your-domain.com
    acme: true
    acmeEmail: your-email@example.com
    
    auth:
      teleportConfig:
        auth_service:
          authentication:
            type: github
            github:
              client_id: "${GITHUB_CLIENT_ID}"
              client_secret: "${GITHUB_CLIENT_SECRET}"
              redirect_url: "https://k8s.your-domain.com/v1/webapi/github/callback"
              teams_to_roles:
                - organization: your-org
                  team: admin
                  roles: ["access", "editor"]
    
    proxy:
      service:
        type: LoadBalancer
        annotations:
          oci.oraclecloud.com/load-balancer-type: "nlb"
          external-dns.alpha.kubernetes.io/hostname: "k8s.your-domain.com,*.k8s.your-domain.com"
```

## 7. Dex 설치 (선택사항 - Kubernetes Dashboard 등을 위한 OIDC)

### 7.1 Dex 설정
```yaml
# infrastructure/controllers/dex.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dex
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: dex
  namespace: flux-system
spec:
  interval: 60m
  url: https://charts.dexidp.io
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: dex
  namespace: dex
spec:
  interval: 30m
  chart:
    spec:
      chart: dex
      version: "0.17.x"
      sourceRef:
        kind: HelmRepository
        name: dex
        namespace: flux-system
  values:
    config:
      issuer: https://dex.your-domain.com
      
      storage:
        type: kubernetes
        config:
          inCluster: true
      
      connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $GITHUB_CLIENT_ID
          clientSecret: $GITHUB_CLIENT_SECRET
          redirectURI: https://dex.your-domain.com/callback
          orgs:
          - name: your-org
      
      staticClients:
      - id: kubernetes
        redirectURIs:
        - 'http://localhost:8000'
        - 'https://dashboard.your-domain.com/oauth/callback'
        name: 'Kubernetes'
        secret: generated-secret
```

## 배포 순서 및 검증

### 1단계: FluxCD 설치 및 기본 구조 설정
```bash
flux bootstrap github --owner=$GITHUB_USER --repository=$GITHUB_REPO --branch=main --path=./clusters/production --personal
git pull
# 디렉터리 구조 생성 및 기본 Kustomization 파일 커밋/푸시
```

### 2단계: 스토리지 (Longhorn)
```bash
# Longhorn 파일 커밋/푸시
flux reconcile kustomization infrastructure-controllers
kubectl -n longhorn-system get pods
```

### 3단계: Ingress 및 DNS
```bash
# NGINX Ingress, External DNS, Cert-Manager 파일 커밋/푸시
flux reconcile kustomization infrastructure-controllers
kubectl -n ingress-nginx get svc
# LoadBalancer IP 확인 후 Cloudflare에 A 레코드 수동 생성 (처음만)
```

### 4단계: Teleport
```bash
# Teleport 파일 커밋/푸시
flux reconcile kustomization infrastructure-controllers
kubectl -n teleport get svc
```

### 5단계: 검증
```bash
# 모든 HelmRelease 상태 확인
flux get helmreleases --all-namespaces

# 인증서 발급 확인
kubectl get certificates --all-namespaces

# Ingress 확인
kubectl get ingress --all-namespaces
```

## 주의사항

1. **ARM 호환성**: 모든 이미지가 ARM64를 지원하는지 확인
2. **리소스 제한**: OCI 무료 티어는 로드밸런서 1개만 지원하므로 NGINX용 Layer 7 LB 사용
3. **DNS 전파**: External DNS 설정 후 DNS 전파까지 시간이 걸릴 수 있음
4. **GitHub OAuth**: Teleport과 Dex용 OAuth 앱은 별도로 생성 필요
5. **시크릿 관리**: 민감한 정보는 Sealed Secrets 또는 SOPS 사용 권장

## 문제 해결

### FluxCD 동기화 문제
```bash
flux logs --all-namespaces --follow
flux get sources git
flux get kustomizations
```

### 인증서 발급 실패
```bash
kubectl describe certificate -n <namespace> <cert-name>
kubectl logs -n cert-manager deployment/cert-manager
```

### Teleport 접속 문제
```bash
kubectl logs -n teleport deployment/teleport-auth
kubectl logs -n teleport deployment/teleport-proxy
```