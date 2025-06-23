variable "compartment_id" {
  type        = string
  description = "The compartment to create the resources in"
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "ap-chuncheon-1"
}

variable "ssh_public_key" {
  description = "SSH Public Key used to access all instances"
  type        = string
}

variable "kubernetes_version" {
  # https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengaboutk8sversions.htm
  description = "Version of Kubernetes"
  type        = string
  default     = "v1.32.1"
}

variable "kubernetes_worker_nodes" {
  description = "Worker node count"
  type        = number
  default     = 2
}

# VCN Configuration
variable "vcn_name" {
  description = "Name of the VCN"
  type        = string
  default     = "s6g-k8s-vcn"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN"
  type        = string
  default     = "s6gk8svcn"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

# Subnet Configuration
variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"  
  type        = string
  default     = "10.0.0.0/24"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "s6g-k8s-cluster"
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
  default     = "s6g-k8s-node-pool"
}

# Node Configuration
variable "node_memory_gbs" {
  description = "Memory in GBs for each node"
  type        = number
  default     = 12
}

variable "node_ocpus" {
  description = "Number of OCPUs for each node"
  type        = number
  default     = 2
}

variable "boot_volume_size_gbs" {
  description = "Boot volume size in GBs"
  type        = number
  default     = 100
}

# Kubernetes Network Configuration
variable "pods_cidr" {
  description = "CIDR block for Kubernetes pods"
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/16"
}
