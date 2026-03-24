resource "kubernetes_namespace" "greenroom" {
  metadata {
    name = "greenroom"
  }
}

resource "kubernetes_default_service_account_v1" "default_service_account_greenroom" {
  metadata {
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  image_pull_secret {
    name = "docker-registry-secret"
  }

  automount_service_account_token = true
}

resource "random_password" "download_secret" {
  length  = 32
  special = true
}

resource "random_password" "rabbitmq_password" {
  length  = 32
  special = true
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

resource "kubernetes_secret" "docker_registry_external_greenroom" {
  metadata {
    name      = "docker-registry-external-secret"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "docker-registry.ebrains.eu" = {
          username = var.docker_registry_external_username
          password = var.docker_registry_external_password
          auth     = base64encode("${var.docker_registry_external_username}:${var.docker_registry_external_password}")
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

resource "kubernetes_secret" "message_bus_greenroom_secret" {
  metadata {
    name      = "message-bus-greenroom-secret"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "Opaque"

  data = {
    "rabbitmq-password" = random_password.rabbitmq_password.result
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [random_password.rabbitmq_password]
}

resource "kubernetes_secret" "download_secret" {
  metadata {
    name      = "download-secret"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  type = "Opaque"

  data = {
    "DOWNLOAD_KEY" = random_password.download_secret.result
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [random_password.download_secret]
}

resource "helm_release" "upload_greenroom" {

  name = "upload-service"

  repository      = "https://pilotdataplatform.github.io/helm-charts/"
  chart           = "upload-service"
  version         = var.upload_chart_version
  namespace       = kubernetes_namespace.greenroom.metadata[0].name
  timeout         = "300"
  atomic          = true
  cleanup_on_fail = true

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
    helm_release.minio,
    helm_release.kafka,
    kubernetes_secret.redis_greenroom_credential,
    kubernetes_secret.minio_greenroom_credential
  ]
}

resource "helm_release" "download_greenroom" {

  name = "download-service"

  repository      = "https://pilotdataplatform.github.io/helm-charts/"
  chart           = "download-service"
  version         = var.download_chart_version
  namespace       = kubernetes_namespace.greenroom.metadata[0].name
  timeout         = "300"
  atomic          = true
  cleanup_on_fail = true

  values = [templatefile("../helm_charts/pilot-hdc/download/values.yaml", {
    EXTERNAL_IP = var.external_ip
  })]

  set {
    name  = "image.tag"
    value = "download-${var.download_app_version}"
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_greenroom_registry.metadata[0].name
  }

  depends_on = [
    helm_release.redis,
    helm_release.minio,
    helm_release.kafka,
    kubernetes_secret.download_secret,
    kubernetes_secret.redis_greenroom_credential,
    kubernetes_secret.minio_greenroom_credential
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "greenroom-storage" {
  metadata {
    name      = "greenroom-storage"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    storage_class_name = "local-path"
  }
}

resource "kubernetes_role_v1" "queue-consumer-job-creator" {
  metadata {
    name      = "queue-consumer-job-creator"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["create"]
  }
}

resource "kubernetes_role_binding_v1" "queue-consumer-job-creator" {
  metadata {
    name      = "queue-consumer-job-creator"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "queue-consumer-job-creator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "queue-consumer"
    namespace = kubernetes_namespace.greenroom.metadata[0].name
  }
}

resource "helm_release" "queue-consumer" {

  name = "queue-consumer-service"

  repository      = "https://pilotdataplatform.github.io/helm-charts/"
  chart           = "queue-service"
  version         = var.queue-consumer_chart_version
  namespace       = kubernetes_namespace.greenroom.metadata[0].name
  timeout         = "300"
  atomic          = true
  cleanup_on_fail = true

  values = [templatefile("../helm_charts/pilot-hdc/queue-consumer/values.yaml", {
    EXTERNAL_IP = var.external_ip
  })]

  set {
    name  = "image.tag"
    value = "consumer-${var.queue-consumer_app_version}"
  }

  set {
    name  = "extraEnv.data_transfer_image"
    value = "docker-registry.ebrains.eu/hdc-services-image/pipelines/filecopy:filecopy-${var.filecopy_app_version}"
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_greenroom_registry.metadata[0].name
  }

  depends_on = [
    helm_release.redis,
    helm_release.minio,
    helm_release.kafka,
    helm_release.message_bus_greenroom,
    kubernetes_secret.message_bus_greenroom_secret,
    kubernetes_secret.redis_greenroom_credential,
  ]
}

resource "helm_release" "queue-producer" {

  name = "queue-producer-service"

  repository      = "https://pilotdataplatform.github.io/helm-charts/"
  chart           = "queue-service"
  version         = var.queue-producer_chart_version
  namespace       = kubernetes_namespace.greenroom.metadata[0].name
  timeout         = "300"
  atomic          = true
  cleanup_on_fail = true

  values = [templatefile("../helm_charts/pilot-hdc/queue-producer/values.yaml", {
    EXTERNAL_IP = var.external_ip
  })]

  set {
    name  = "image.tag"
    value = "producer-${var.queue-producer_app_version}"
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_greenroom_registry.metadata[0].name
  }

  depends_on = [
    helm_release.redis,
    helm_release.minio,
    helm_release.kafka,
    helm_release.message_bus_greenroom,
    kubernetes_secret.message_bus_greenroom_secret,
  ]
}
