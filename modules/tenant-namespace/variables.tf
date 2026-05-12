# modules/tenant-namespace/variables.tf

variable "tenant_name" {
  description = "Name of the tenant"
  type        = string
}

variable "tenant_namespace" {
  description = "Kubernetes namespace for the tenant (defaults to tenant-{tenant_name})"
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "ops_manager_namespace" {
  description = "Namespace where Ops Manager is deployed"
  type        = string
  default     = "opsmanager"
}

variable "ops_manager_url" {
  description = "Ops Manager URL"
  type        = string
}

variable "ops_manager_user" {
  description = "Ops Manager user for this tenant"
  type        = string
  sensitive   = true
}

variable "ops_manager_public_key" {
  description = "Ops Manager public API key for this tenant"
  type        = string
  sensitive   = true
}

variable "ops_manager_org_id" {
  description = "Ops Manager organization ID"
  type        = string
}

variable "ops_manager_project_id" {
  description = "Ops Manager project ID for this tenant"
  type        = string
}

# Resource quota variables
variable "enable_resource_quota" {
  description = "Enable resource quotas for tenant namespace"
  type        = bool
  default     = true
}

variable "cpu_quota" {
  description = "CPU quota for tenant namespace"
  type        = string
  default     = "10"
}

variable "memory_quota" {
  description = "Memory quota for tenant namespace"
  type        = string
  default     = "20Gi"
}

variable "storage_quota" {
  description = "Storage quota for tenant namespace"
  type        = string
  default     = "100Gi"
}

variable "pvc_quota" {
  description = "Maximum number of PVCs in tenant namespace"
  type        = string
  default     = "10"
}

variable "pods_quota" {
  description = "Maximum number of pods in tenant namespace"
  type        = string
  default     = "20"
}

# Limit range variables
variable "enable_limit_range" {
  description = "Enable limit ranges for tenant namespace"
  type        = bool
  default     = true
}

variable "default_cpu_limit" {
  description = "Default CPU limit per container"
  type        = string
  default     = "1"
}

variable "default_memory_limit" {
  description = "Default memory limit per container"
  type        = string
  default     = "2Gi"
}

variable "default_cpu_request" {
  description = "Default CPU request per container"
  type        = string
  default     = "100m"
}

variable "default_memory_request" {
  description = "Default memory request per container"
  type        = string
  default     = "256Mi"
}

# Network policy variables
variable "enable_network_policy" {
  description = "Enable network policies for tenant isolation"
  type        = bool
  default     = true
}

# Per-tenant MongoDB operator deployment
variable "deploy_mongodb_operator" {
  description = "Deploy a MongoDB Enterprise Operator instance in this tenant namespace"
  type        = bool
  default     = true
}

variable "kubernetes_operator_version" {
  description = "MongoDB Kubernetes Operator Helm chart version to use for tenant operator"
  type        = string
  default     = "1.8.0"
}

# MongoDB Search Configuration
variable "enable_search" {
  description = "Enable MongoDB Search for this tenant (requires MongoDB 8.2.0+)"
  type        = bool
  default     = false
}

variable "mongodb_version" {
  description = "MongoDB version to deploy (8.2.0-ent or higher required for search)"
  type        = string
  default     = "8.2.0-ent"
}

variable "mongodb_members" {
  description = "Number of MongoDB replica set members"
  type        = number
  default     = 3
}

variable "search_cpu_limit" {
  description = "CPU limit for MongoDB Search pods"
  type        = string
  default     = "3"
}

variable "search_memory_limit" {
  description = "Memory limit for MongoDB Search pods"
  type        = string
  default     = "5Gi"
}

variable "search_cpu_request" {
  description = "CPU request for MongoDB Search pods"
  type        = string
  default     = "2"
}

variable "search_memory_request" {
  description = "Memory request for MongoDB Search pods"
  type        = string
  default     = "3Gi"
}

# External MongoDB source (for Search with external clusters)
variable "search_external_enabled" {
  description = "Enable MongoDB Search against an external MongoDB cluster"
  type        = bool
  default     = false
}

variable "search_external_host_and_ports" {
  description = "List of host:port entries for the external MongoDB cluster"
  type        = list(string)
  default     = []
}

variable "search_external_keyfile_secret_name" {
  description = "Kubernetes secret name containing the keyfile for external MongoDB auth"
  type        = string
  default     = ""
}

variable "search_external_keyfile_secret_key" {
  description = "Key in the secret holding the keyfile content"
  type        = string
  default     = ""
}

variable "search_external_username" {
  description = "Username for connecting to the external MongoDB cluster"
  type        = string
  default     = ""
}

variable "search_external_password_secret_name" {
  description = "Kubernetes secret name containing the password for the external MongoDB user"
  type        = string
  default     = ""
}

variable "search_external_password_secret_key" {
  description = "Key in the password secret"
  type        = string
  default     = ""
}

variable "ca_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer for CA certificates"
  type        = string
  default     = "mongodb-ca-issuer"
}

variable "ca_secret_name" {
  description = "Name of the secret containing the CA certificate"
  type        = string
  default     = "mongodb-ca-secret"
}

variable "ca_cert_namespace" {
  description = "Namespace where the CA certificate is stored"
  type        = string
  default     = "cert-manager"
}
