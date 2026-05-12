# outputs.tf

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "kubernetes_operator_version" {
  description = "MongoDB Kubernetes Operator Helm chart version deployed"
  value       = var.kubernetes_operator_version
}

output "ops_manager_version" {
  description = "MongoDB Ops Manager version deployed"
  value       = var.ops_manager_version
}

output "ops_manager_access" {
  description = "Instructions for accessing Ops Manager"
  value       = "Ops Manager is deployed in the 'opsmanager' namespace. Access via: kubectl port-forward svc/ops-manager-svc-ext 8080:8080 -n opsmanager, then visit http://localhost:8080"
}

output "tenant_namespaces" {
  description = "Map of tenant names to their Kubernetes namespaces"
  value = {
    for tenant_key, tenant_module in module.tenant_namespace :
    tenant_key => tenant_module.namespace
  }
}

output "tenant_details" {
  description = "Details about each tenant namespace"
  value = {
    for tenant_key, tenant_module in module.tenant_namespace :
    tenant_key => {
      namespace           = tenant_module.namespace
      ops_manager_secret  = tenant_module.ops_manager_secret_name
      service_account     = tenant_module.service_account_name
    }
  }
}
