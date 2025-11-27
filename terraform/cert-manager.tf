resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {

  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert-manager.metadata[0].name
  create_namespace = false
  timeout          = "300"
  version          = var.certmanager_chart_version

  values = [file("../helm_charts/cert-manager/values.yaml")]
}

resource "null_resource" "wait_for_cert_manager" {
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager && kubectl wait --for=condition=Established --timeout=60s crd/clusterissuers.cert-manager.io"
  }
  depends_on = [helm_release.cert-manager]
}

resource "kubectl_manifest" "clusterissuer_selfsigned" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
YAML

  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    null_resource.wait_for_cert_manager
  ]
}

resource "kubectl_manifest" "clusterissuer_letsencrypt" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: acascais@indocresearch.org
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: traefik
YAML

  depends_on = [
    kubernetes_namespace.cert-manager,
    helm_release.cert-manager,
    null_resource.wait_for_cert_manager
  ]
}
