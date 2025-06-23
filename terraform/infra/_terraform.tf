terraform {

  # S3 백엔드 임시 비활성화 (x-amz-content-sha256 오류 해결 필요)
  # backend "s3" {
  #   bucket = "terraform-states"
  #   key    = "infra/terraform.tfstate"
  #   endpoints = {
  #     # ap-chuncheon-1 리전의 네임스페이스를 확인해서 수정해주세요
  #     # 형식: https://<namespace>.compat.objectstorage.<region>.oraclecloud.com
  #     s3 = "https://axejwclweluc.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
  #   }
  #   region                      = "ap-chuncheon-1"
  #   shared_credentials_files    = ["~/.aws/credentials"]
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_requesting_account_id  = true
  #   skip_metadata_api_check     = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }

  required_providers {
    jq = {
      source  = "massdriver-cloud/jq"
      version = "0.2.1"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 7.2.0"
    }
  }
}
