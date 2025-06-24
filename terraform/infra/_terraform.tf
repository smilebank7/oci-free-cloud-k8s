terraform {

  backend "s3" {
    bucket = "terraform-states"
    key    = "infra/terraform.tfstate"
    endpoint = "https://axejwclweluc.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    region = "ap-chuncheon-1"
    shared_credentials_file     = "~/.oci/config"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }

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