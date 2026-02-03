resource "kubernetes_namespace" "greenroom" {
  metadata {
    name = "greenroom"
  }
}

resource "kubernetes_secret" "docker_greenroom_registry" {
  metadata {
    name      = "docker-registry-secret"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "docker-registry.ebrains.eu" = {
          username = var.docker_registry_username
          password = var.docker_registry_password
          auth     = base64encode("${var.docker_registry_username}:${var.docker_registry_password}")
        }
      }
    })
  }

  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_secret" "minio_greenroom_credential" {
  metadata {
    name      = "minio-credential"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "Opaque"

  data = {
    "MINIO_ACCESS_KEY" = data.kubernetes_secret.minio_credential.data["root-user"]
    "MINIO_SECRET_KEY" = data.kubernetes_secret.minio_credential.data["root-password"]
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [data.kubernetes_secret.minio_credential]
}

resource "kubernetes_secret" "redis_greenroom_credential" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "Opaque"

  data = {
    "REDIS_PASSWORD" = data.kubernetes_secret.redis_credential.data["redis-password"]
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [data.kubernetes_secret.redis_credential]
}

resource "helm_release" "upload_greenroom" {

  name = "upload-service"

  repository = "https://pilotdataplatform.github.io/helm-charts/"
  chart      = "upload-service"
  version    = var.upload_chart_version
  namespace  = kubernetes_namespace.greenroom.metadata[0].name
  timeout    = "300"

  values = [templatefile("../helm_charts/pilot-hdc/upload/values.yaml", {
    EXTERNAL_IP = var.external_ip
  })]

  set {
    name  = "image.tag"
    value = "upload-${var.upload_app_version}"
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_greenroom_registry.metadata[0].name
  }

  depends_on = [
    helm_release.redis,
    helm_release.keycloak,
    kubernetes_secret.redis_greenroom_credential,
    kubernetes_secret.minio_greenroom_credential,
    kubernetes_namespace.minio
  ]
}
