# modules/mongodb-operator/main.tf

variable "kubernetes_operator_version" {
  description = "MongoDB Kubernetes Operator Helm chart version"
  type        = string
  default     = "1.8.0"
}

resource "helm_release" "mongodb_enterprise_operator" {
  name             = "mongodb-kubernetes"
  repository       = "https://mongodb.github.io/helm-charts"
  chart            = "mongodb-kubernetes"
  version          = var.kubernetes_operator_version
  namespace        = "opsmanager"
  create_namespace = true

  values = [
    yamlencode({
      operator = {
        name = "mongodb-enterprise-operator"
      }
    })
  ]
}

# Apply/upgrade CRDs explicitly to ensure MongoDBSearch fields exist (helm upgrade sometimes skips CRDs)
resource "null_resource" "apply_mongodb_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      helm repo add mongodb https://mongodb.github.io/helm-charts >/dev/null
      helm repo update >/dev/null
      # Apply built-in CRDs from the chart
      helm show crds mongodb/mongodb-kubernetes --version ${var.kubernetes_operator_version} |
        kubectl apply -f -
      # Apply MongoDBSearch CRD (not yet shipped in the chart)
      kubectl apply -f ${path.module}/crds/mongodbsearches.mongodb.com-crd.yaml
    EOT
  }

  depends_on = [helm_release.mongodb_enterprise_operator]
}

# Ensure the MongoDBSearch CRD is present before downstream modules run
resource "null_resource" "wait_for_mongodbsearch_crd" {
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 30); do
        if kubectl get crd mongodbsearches.mongodb.com >/dev/null 2>&1; then
          exit 0
        fi
        sleep 2
      done
      echo "MongoDBSearch CRD not available after waiting" >&2
      exit 1
    EOT
  }

  depends_on = [null_resource.apply_mongodb_crds]
}