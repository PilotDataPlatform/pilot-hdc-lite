resource "kubernetes_namespace" "minio" {
  metadata {
    name = "minio"
  }
}

resource "helm_release" "minio" {

  name = "minio"

  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "minio"
  namespace        = kubernetes_namespace.minio.metadata[0].name
  version          = var.minio_chart_version
  create_namespace = false
  timeout          = "300"

  values = [file("../helm_charts/minio/values.yaml")]

  # Override values with auto-detected IP
  # Use nip.io DNS service for dynamic hostname resolution
  set {
    name  = "ingress.hostname"
    value = "minio-console.${local.node_ip}.nip.io"
  }

  set {
    name  = "apiIngress.hostname"
    value = "minio-api.${local.node_ip}.nip.io"
  }

  depends_on = [
    kubernetes_namespace.minio
  ]
}
