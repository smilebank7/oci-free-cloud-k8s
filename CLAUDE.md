# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Oracle Cloud Infrastructure (OCI) Kubernetes cluster setup leveraging the OCI Always Free tier. The infrastructure is managed with Terraform and the Kubernetes applications are deployed using FluxCD (via the new flux-operator).

Key architecture points:
- Uses ARM-based instances (VM.Standard.A1.Flex) due to free tier limitations
- 2 worker nodes with 2 oCPUs and 12GB memory each
- Longhorn for persistent storage
- NGINX ingress on Layer 7 LB, Teleport on Layer 4 LB
- External DNS syncing to Cloudflare
- GitHub SSO via Dex and Teleport

## Terraform Structure

The Terraform code is split into two independent parts:

1. **Infrastructure** (`terraform/infra/`): Provisions OCI resources up to a working K8s API endpoint
2. **Config** (`terraform/config/`): K8s-specific configurations that require the cluster to exist

Note: The `terraform/config` directory was removed intentionally. All K8s configurations are now managed through FluxCD.

## Known Issues

### S3 Backend (OCI Object Storage)
현재 OCI Object Storage의 S3 호환성 문제로 인해 terraform state를 원격에 저장할 때 다음 오류가 발생합니다:
```
x-amz-content-sha256 must be UNSIGNED-PAYLOAD or a valid sha256 value
```

**임시 해결책:** `terraform/infra/_terraform.tf`에서 S3 백엔드를 주석 처리하고 로컬 백엔드를 사용합니다.

**향후 해결 방향:**
1. OCI Provider의 `http` 백엔드 사용 고려
2. AWS S3 SDK 버전 호환성 확인
3. Customer Secret Keys 재생성 및 테스트

## Common Commands

### Terraform State Backend
```bash
# Create the initial S3 bucket for Terraform state (one-time setup)
oci os bucket create --name terraform-states --versioning Enabled --compartment-id <compartment-id>

# Customer Secret Keys 생성 (S3 호환성을 위해)
oci iam customer-secret-key create --user-id <user-ocid> --display-name "terraform-s3"
# ~/.aws/credentials 파일에 반환된 key/secret 저장
```

### Infrastructure Management
```bash
cd terraform/infra/

# Initialize and apply infrastructure
terraform init
terraform plan -var-file=*.tfvars  # requires private tfvars file
terraform apply -var-file=*.tfvars

# Access the generated kubeconfig
export KUBECONFIG=$(pwd)/.kube.config
```

### Kubernetes Version Upgrade
```bash
cd terraform/infra/

# Check available upgrades
oci ce cluster get --cluster-id $(terraform output --raw k8s_cluster_id) | jq -r '.data."available-kubernetes-upgrades"'

# Update the version in _variables.tf
# Then apply terraform changes
terraform apply -var-file=*.tfvars

# For node upgrades, drain and terminate nodes one by one:
kubectl drain <node-name> --force --ignore-daemonsets --delete-emptydir-data
kubectl cordon <node-name>
# Then terminate the instance via OCI console or CLI
# Wait for Longhorn volumes to sync before proceeding to next node
```

### Development Workflow

There are no traditional build/test commands for this infrastructure repository. The main workflows involve:

1. **Terraform validation**: `terraform validate` and `terraform fmt`
2. **Kubernetes access**: Use the generated kubeconfig or Teleport for cluster access
3. **FluxCD reconciliation**: Triggered automatically via GitHub webhook on commits

### Required Variables

When running Terraform, you'll need a private `.tfvars` file with:
- `compartment_id`: OCI compartment OCID
- `github_pat`: GitHub fine-grained PAT with permissions for contents (R/W), commit statuses (R/W), webhooks (R/W)
- Additional OCI-specific variables as needed

The GitHub PAT must also be stored in OCI Vault as `github-fluxcd-token` for FluxCD commit status annotations.

## Important Notes

- The gitops directory mentioned in README was intentionally removed - all K8s configs are managed via FluxCD
- When the terraform config first runs, it may fail creating ClusterSecretStore until external-secrets is deployed by Flux
- The cluster uses ARM architecture exclusively - ensure all container images support ARM64
- Teleport requires wildcard DNS which is why DNS was moved from OCI to Cloudflare