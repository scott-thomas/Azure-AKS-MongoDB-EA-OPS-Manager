# modules/tenant-namespace/main.tf

# Create a namespace for each tenant
resource "kubernetes_namespace_v1" "tenant" {
  metadata {
    name = var.tenant_namespace

    labels = {
      tenant      = var.tenant_name
      environment = var.environment
      managed-by  = "terraform"
    }

    annotations = {
      "ops-manager-project" = var.ops_manager_project_id
    }
  }
}

# Credentials secret for the MongoDB operator to authenticate with Ops Manager
# Field names (user / publicApiKey) are required by the MongoDB Kubernetes Operator spec.
resource "kubernetes_secret" "ops_manager_credentials" {
  metadata {
    name      = "${var.tenant_name}-ops-manager-credentials"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  type = "Opaque"

  data = {
    user         = var.ops_manager_user
    publicApiKey = var.ops_manager_public_key
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# ConfigMap for the MongoDB operator to locate the Ops Manager instance and project
# baseUrl and projectName are required by the MongoDB Kubernetes Operator spec.
resource "kubernetes_config_map" "ops_manager_config" {
  metadata {
    name      = "${var.tenant_name}-ops-manager-config"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  data = {
    baseUrl     = var.ops_manager_url
    projectName = "${var.tenant_name}-project"
    orgId       = var.ops_manager_org_id
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Resource quotas for the tenant namespace
resource "kubernetes_resource_quota" "tenant_quota" {
  count = var.enable_resource_quota ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-quota"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = var.cpu_quota
      "requests.memory"        = var.memory_quota
      "requests.storage"       = var.storage_quota
      "persistentvolumeclaims" = var.pvc_quota
      "pods"                   = var.pods_quota
    }
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Limit ranges for the tenant namespace
resource "kubernetes_limit_range" "tenant_limits" {
  count = var.enable_limit_range ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-limits"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = var.default_cpu_limit
        memory = var.default_memory_limit
      }

      default_request = {
        cpu    = var.default_cpu_request
        memory = var.default_memory_request
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Network policy to isolate tenant namespace
resource "kubernetes_network_policy" "tenant_isolation" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-isolation"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace
    ingress {
      from {
        pod_selector {}
      }
    }

    # Allow ingress from ops-manager namespace (matched by namespace name)
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.ops_manager_namespace
          }
        }
      }
    }

    # Allow egress to same namespace
    egress {
      to {
        pod_selector {}
      }
    }

    # Allow egress to ops-manager namespace (matched by namespace name)
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.ops_manager_namespace
          }
        }
      }
    }

    # Allow egress to kube-dns
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    # Allow egress to external (for pulling images, etc.)
    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = ["169.254.169.254/32"]
        }
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Service account for MongoDB deployments in tenant namespace
resource "kubernetes_service_account" "mongodb" {
  metadata {
    name      = "mongodb-service-account"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Optional per-tenant MongoDB Enterprise Operator instance
resource "helm_release" "mongodb_enterprise_operator_tenant" {
  count            = var.deploy_mongodb_operator ? 1 : 0
  name             = "mongodb-kubernetes-${var.tenant_name}"
  repository       = "https://mongodb.github.io/helm-charts"
  chart            = "mongodb-kubernetes"
  version          = var.kubernetes_operator_version
  namespace        = kubernetes_namespace_v1.tenant.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      operator = {
        name = "mongodb-enterprise-operator-${var.tenant_name}"
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.tenant]
}

# ============================================================================
# MongoDB Search Resources (Optional)
# ============================================================================

# Create ConfigMap with CA certificate for TLS
# TLS is always required (mongodb manifests have tls.enabled: true), so this is always created.
resource "kubernetes_config_map" "ca_bundle" {
  metadata {
    name      = "${var.tenant_namespace}-ca-configmap"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  # Read CA certificate from cert-manager namespace
  data = {
    "ca-pem"     = data.kubernetes_secret.ca_cert.data["ca.crt"]
    "mms-ca.crt" = data.kubernetes_secret.ca_cert.data["ca.crt"]
    "ca.crt"     = data.kubernetes_secret.ca_cert.data["ca.crt"]
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Data source to read CA certificate
data "kubernetes_secret" "ca_cert" {
  metadata {
    name      = var.ca_secret_name
    namespace = var.ca_cert_namespace
  }
}

# TLS Certificate for MongoDB Server
resource "null_resource" "mongodb_server_cert" {
  # TLS is always required — the MongoDB manifests have tls.enabled: true
  count = 1

  triggers = {
    tenant_namespace = var.tenant_namespace
    tenant_name      = var.tenant_name
    issuer_name      = var.ca_issuer_name
    members          = var.mongodb_members
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: ${var.tenant_name}-mongodb-server-tls
        namespace: ${var.tenant_namespace}
      spec:
        secretName: ${var.tenant_name}-mongodb-cert
        issuerRef:
          name: ${var.ca_issuer_name}
          kind: ClusterIssuer
        duration: 240h0m0s
        renewBefore: 120h0m0s
        usages:
          - "digital signature"
          - "key encipherment"
          - "server auth"
          - "client auth"
        dnsNames:
          - "localhost"
          - "${var.tenant_name}-mongodb-svc.${var.tenant_namespace}.svc.cluster.local"
          - "*.${var.tenant_name}-mongodb-svc.${var.tenant_namespace}.svc.cluster.local"
      %{for i in range(var.mongodb_members)}
          - "${var.tenant_name}-mongodb-${i}"
          - "${var.tenant_name}-mongodb-${i}.${var.tenant_name}-mongodb-svc.${var.tenant_namespace}.svc.cluster.local"
      %{endfor}
        ipAddresses:
          - "127.0.0.1"
    EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete certificate ${self.triggers.tenant_name}-mongodb-server-tls -n ${self.triggers.tenant_namespace} --ignore-not-found=true"
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# TLS Certificate for MongoDB Search
resource "null_resource" "mongodb_search_cert" {
  count = var.enable_search ? 1 : 0

  triggers = {
    tenant_namespace = var.tenant_namespace
    tenant_name      = var.tenant_name
    issuer_name      = var.ca_issuer_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: ${var.tenant_name}-mongodb-search-tls
        namespace: ${var.tenant_namespace}
      spec:
        secretName: ${var.tenant_namespace}-search-tls
        issuerRef:
          name: ${var.ca_issuer_name}
          kind: ClusterIssuer
        duration: 240h0m0s
        renewBefore: 120h0m0s
        usages:
          - "digital signature"
          - "key encipherment"
          - "server auth"
          - "client auth"
        dnsNames:
          - "${var.tenant_name}-mongodb-search-svc.${var.tenant_namespace}.svc.cluster.local"
          - "*.${var.tenant_name}-mongodb-search-svc.${var.tenant_namespace}.svc.cluster.local"
          - "${var.tenant_name}-mongodb-search-0.${var.tenant_name}-mongodb-search-svc.${var.tenant_namespace}.svc.cluster.local"
          - "${var.tenant_name}-mongodb-search-0"
    EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete certificate ${self.triggers.tenant_name}-mongodb-search-tls -n ${self.triggers.tenant_namespace} --ignore-not-found=true"
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Secret for MongoDB Search sync user password
resource "kubernetes_secret" "search_sync_password" {
  count = var.enable_search ? 1 : 0

  metadata {
    name      = "${var.tenant_namespace}-search-sync-source-password"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }

  type = "Opaque"

  data = {
    password = "${var.tenant_name}-search-sync-${random_password.search_sync_password[0].result}"
  }

  depends_on = [kubernetes_namespace_v1.tenant]
}

# Generate random password for search sync user
resource "random_password" "search_sync_password" {
  count = var.enable_search ? 1 : 0

  length  = 32
  special = true
}

# MongoDBUser for search sync
resource "null_resource" "search_sync_user" {
  count = var.enable_search ? 1 : 0

  triggers = {
    tenant_namespace = var.tenant_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: mongodb.com/v1
      kind: MongoDBUser
      metadata:
        name: search-sync-source-user
        namespace: ${var.tenant_namespace}
      spec:
        username: search-sync-source
        db: admin
        mongodbResourceRef:
          name: ${var.tenant_name}-mongodb
        passwordSecretKeyRef:
          name: ${var.tenant_namespace}-search-sync-source-password
          key: password
        roles:
          - name: searchCoordinator
            db: admin
    EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete mongodbuser search-sync-source-user -n ${self.triggers.tenant_namespace} --ignore-not-found=true"
  }

  depends_on = [
    kubernetes_secret.search_sync_password,
    helm_release.mongodb_enterprise_operator_tenant
  ]
}

# MongoDBSearch Custom Resource
resource "null_resource" "mongodb_search" {
  count = var.enable_search ? 1 : 0

  triggers = {
    tenant_namespace = var.tenant_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: mongodb.com/v1
      kind: MongoDBSearch
      metadata:
        name: ${var.tenant_name}-mongodb
        namespace: ${var.tenant_namespace}
      spec:
        security:
          tls:
            certificateKeySecretRef:
              name: ${var.tenant_namespace}-search-tls
%{ if var.search_external_enabled }
        source:
          external:
            hostAndPorts:
%{ for hp in var.search_external_host_and_ports }
              - "${hp}"
%{ endfor }
            keyfileSecretRef:
              name: ${var.search_external_keyfile_secret_name}
              key: ${var.search_external_keyfile_secret_key}
          username: ${var.search_external_username}
          passwordSecretRef:
            name: ${var.search_external_password_secret_name}
            key: ${var.search_external_password_secret_key}
%{ endif }
        resourceRequirements:
          limits:
            cpu: "${var.search_cpu_limit}"
            memory: "${var.search_memory_limit}"
          requests:
            cpu: "${var.search_cpu_request}"
            memory: "${var.search_memory_request}"
    EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete mongodbsearch ${self.triggers.tenant_namespace} -n ${self.triggers.tenant_namespace} --ignore-not-found=true"
  }

  depends_on = [
    null_resource.mongodb_server_cert,
    null_resource.mongodb_search_cert,
    null_resource.search_sync_user,
    helm_release.mongodb_enterprise_operator_tenant
  ]
}
