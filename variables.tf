# variables.tf

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "created_by" {
  description = "User or service that created the resources"
  type        = string
  default     = "Terraform"
}

variable "expired_on" {
  description = "Expiration date for the resources (format: YYYY-MM-DD)"
  type        = string
  default     = "2026-06-15" # 6 months from December 15, 2025
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "ops_manager_url" {
  description = "URL for MongoDB Ops Manager"
  type        = string
}

variable "ops_manager_admin_user" {
  description = "Admin username for Ops Manager"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "ops_manager_api_key" {
  description = "API key for Ops Manager"
  type        = string
  sensitive   = true
}

variable "ops_manager_version" {
  description = "MongoDB Ops Manager version"
  type        = string
  default     = "8.0.22"
}

variable "kubernetes_operator_version" {
  description = "MongoDB Kubernetes Operator Helm chart version"
  type        = string
  default     = "1.8.0"
}

variable "ops_manager_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Ops Manager (port 8080) through the AKS cluster"
  type        = list(string)
  default     = []
}

variable "tenants" {
  description = "Map of tenants with their Ops Manager credentials"
  type = map(object({
    ops_manager_user       = string
    ops_manager_public_key = string
    ops_manager_org_id     = string
    ops_manager_project_id = string
    cpu_quota              = optional(string, "10")
    memory_quota           = optional(string, "20Gi")
    storage_quota          = optional(string, "100Gi")

    # MongoDB Search Configuration
    enable_search         = optional(bool, false)
    mongodb_version       = optional(string, "8.2.6-ent")
    mongodb_members       = optional(number, 3)
    search_cpu_limit      = optional(string, "3")
    search_memory_limit   = optional(string, "5Gi")
    search_cpu_request    = optional(string, "2")
    search_memory_request = optional(string, "3Gi")
  }))
  default = {}
  # Note: sensitive = true removed to allow for_each usage
  # Store sensitive values in terraform.tfvars and add it to .gitignore
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "mongodb-aks-cluster"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "aks-mongodb-rg"
}
