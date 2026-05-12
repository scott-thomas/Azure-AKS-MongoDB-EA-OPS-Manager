# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "aks" {
  source = "./modules/aks"

  created_by  = var.created_by
  expired_on  = var.expired_on
  environment = var.environment

  cluster_name              = var.cluster_name
  ops_manager_allowed_cidrs = var.ops_manager_allowed_cidrs
  resource_group_name       = var.resource_group_name
}

# Connect to the AKS cluster
# IMPORTANT: Run 'az aks get-credentials --resource-group <rg-name> --name <cluster-name>' 
# before running terraform plan/apply
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}


# Deploy MongoDB Enterprise Operator in its own namespace
module "mongodb_operator" {
  source = "./modules/mongodb-operator"

  kubernetes_operator_version = var.kubernetes_operator_version

  depends_on = [module.aks]
}

# Deploy cert-manager for TLS certificate management (required for MongoDB Search)
module "cert_manager" {
  source = "./modules/cert-manager"

  namespace = "cert-manager"

  depends_on = [module.aks]
}

# Create tenant namespaces dynamically
module "tenant_namespace" {
  source   = "./modules/tenant-namespace"
  for_each = var.tenants

  tenant_name            = each.key
  tenant_namespace       = "tenant-${each.key}"
  environment            = var.environment
  ops_manager_namespace  = "opsmanager"
  ops_manager_url        = var.ops_manager_url
  ops_manager_user       = each.value.ops_manager_user
  ops_manager_public_key = each.value.ops_manager_public_key
  ops_manager_org_id     = each.value.ops_manager_org_id
  ops_manager_project_id = each.value.ops_manager_project_id

  # Resource quotas
  cpu_quota                   = lookup(each.value, "cpu_quota", "10")
  memory_quota                = lookup(each.value, "memory_quota", "20Gi")
  storage_quota               = lookup(each.value, "storage_quota", "100Gi")
  kubernetes_operator_version = var.kubernetes_operator_version

  # MongoDB Search configuration
  enable_search         = lookup(each.value, "enable_search", false)
  mongodb_version       = lookup(each.value, "mongodb_version", "8.2.0-ent")
  mongodb_members       = lookup(each.value, "mongodb_members", 3)
  search_cpu_limit      = lookup(each.value, "search_cpu_limit", "3")
  search_memory_limit   = lookup(each.value, "search_memory_limit", "5Gi")
  search_cpu_request    = lookup(each.value, "search_cpu_request", "2")
  search_memory_request = lookup(each.value, "search_memory_request", "3Gi")

  # Certificate manager configuration
  ca_issuer_name    = module.cert_manager.ca_issuer_name
  ca_secret_name    = module.cert_manager.ca_secret_name
  ca_cert_namespace = module.cert_manager.ca_cert_namespace

  depends_on = [module.mongodb_operator, module.cert_manager]
}
