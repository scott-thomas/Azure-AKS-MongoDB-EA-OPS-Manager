# modules/cert-manager/variables.tf

variable "namespace" {
  description = "Namespace to deploy cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.16.2"
}

variable "selfsigned_issuer_name" {
  description = "Name of the self-signed ClusterIssuer"
  type        = string
  default     = "selfsigned-bootstrap-issuer"
}

variable "ca_cert_name" {
  description = "Name of the CA certificate"
  type        = string
  default     = "mongodb-ca"
}

variable "ca_secret_name" {
  description = "Name of the secret containing the CA certificate"
  type        = string
  default     = "mongodb-ca-secret"
}

variable "ca_issuer_name" {
  description = "Name of the CA ClusterIssuer"
  type        = string
  default     = "mongodb-ca-issuer"
}
