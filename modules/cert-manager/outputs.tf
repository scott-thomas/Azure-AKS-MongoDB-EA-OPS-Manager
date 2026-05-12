# modules/cert-manager/outputs.tf

output "namespace" {
  description = "Namespace where cert-manager is deployed"
  value       = var.namespace
}

output "ca_issuer_name" {
  description = "Name of the CA ClusterIssuer"
  value       = var.ca_issuer_name
}

output "ca_secret_name" {
  description = "Name of the secret containing the CA certificate"
  value       = var.ca_secret_name
}

output "ca_cert_namespace" {
  description = "Namespace where the CA certificate is stored"
  value       = var.namespace
}

output "ready" {
  description = "Indicates that cert-manager is ready"
  value       = true
  depends_on  = [time_sleep.wait_for_cert_infrastructure]
}

