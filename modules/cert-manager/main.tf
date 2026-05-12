# modules/cert-manager/main.tf

# Deploy cert-manager via Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  namespace        = var.namespace
  create_namespace = true
  version          = var.cert_manager_version

  set {
    name  = "crds.enabled"
    value = "true"
  }

  # Wait for cert-manager to be ready before continuing
  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# Create certificate infrastructure using kubectl
resource "null_resource" "cert_infrastructure" {
  # Trigger recreation when cert-manager version changes
  triggers = {
    cert_manager_version = var.cert_manager_version
    selfsigned_issuer    = var.selfsigned_issuer_name
    ca_issuer            = var.ca_issuer_name
  }

  # Create self-signed ClusterIssuer
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: ${var.selfsigned_issuer_name}
      spec:
        selfSigned: {}
      EOF
    EOT
  }

  # Wait for self-signed issuer to be ready
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready clusterissuer ${var.selfsigned_issuer_name} --timeout=120s || true"
  }

  # Create CA certificate
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: ${var.ca_cert_name}
        namespace: ${var.namespace}
      spec:
        isCA: true
        commonName: ${var.ca_cert_name}
        secretName: ${var.ca_secret_name}
        privateKey:
          algorithm: ECDSA
          size: 256
        issuerRef:
          name: ${var.selfsigned_issuer_name}
          kind: ClusterIssuer
      EOF
    EOT
  }

  # Wait for CA certificate to be ready
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready certificate ${var.ca_cert_name} -n ${var.namespace} --timeout=180s || true"
  }

  # Create CA ClusterIssuer
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: ${var.ca_issuer_name}
      spec:
        ca:
          secretName: ${var.ca_secret_name}
      EOF
    EOT
  }

  # Wait for CA issuer to be ready
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready clusterissuer ${var.ca_issuer_name} --timeout=120s || true"
  }

  # Cleanup on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete clusterissuer ${self.triggers.ca_issuer} --ignore-not-found=true
      kubectl delete certificate ${self.triggers.selfsigned_issuer} -n cert-manager --ignore-not-found=true || true
      kubectl delete clusterissuer ${self.triggers.selfsigned_issuer} --ignore-not-found=true
    EOT
  }

  depends_on = [helm_release.cert_manager]
}

# Wait for cert infrastructure to be ready
resource "time_sleep" "wait_for_cert_infrastructure" {
  create_duration = "10s"

  depends_on = [null_resource.cert_infrastructure]
}
