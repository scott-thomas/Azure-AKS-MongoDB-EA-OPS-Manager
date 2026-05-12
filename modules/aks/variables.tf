# modules/aks/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "aks-mongodb-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-mongodb-cluster"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aksmongodb"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 4
}

variable "vm_size" {
  description = "Size of the VMs in the node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "created_by" {
  description = "User or service that created the resources"
  type        = string
  default     = "Terraform"
}

variable "expired_on" {
  description = "Expiration date for the resources (format: YYYY-MM-DD)"
  type        = string
  default     = "2026-06-15"  # 6 months from December 15, 2025
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}

# Virtual network configuration for AKS
variable "vnet_address_space" {
  description = "Address space for the AKS virtual network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the AKS node subnet"
  type        = string
  default     = "10.10.0.0/24"
}

# IP ranges allowed to reach Ops Manager (port 8080) via the AKS node NSG
variable "ops_manager_allowed_cidrs" {
  description = "List of CIDR blocks allowed to reach Ops Manager (port 8080) via the AKS node NSG. Leave empty to skip creating the allow rule."
  type        = list(string)
  default     = []
}
