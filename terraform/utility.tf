resource "kubernetes_namespace" "utility" {
  metadata {
    name = "utility"
  }
}

resource "kubernetes_secret" "docker_registry" {
  metadata {
    name      = "docker-registry-secret"
    namespace = kubernetes_namespace.utility.metadata[0].name
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

resource "kubernetes_secret" "docker_registry_external" {
  metadata {
    name      = "docker-registry-external-secret"
    namespace = kubernetes_namespace.utility.metadata[0].name
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

resource "kubernetes_secret" "rsa_public_key" {
  metadata {
    name      = "rsa-public-key-secret"
    namespace = kubernetes_namespace.utility.metadata[0].name
  }

  type = "Opaque"

  data = {
    "rsa-public-key" = var.rsa_public_key
  }

  lifecycle {
    ignore_changes = [data]
  }
}

# Read the existing postgres secret
data "kubernetes_secret" "postgres_credential" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.utility.metadata[0].name
  }
  depends_on = [helm_release.postgres]
}

# Read the existing minio secret
data "kubernetes_secret" "minio_credential" {
  metadata {
    name      = "minio"
    namespace = "minio"
  }
}

resource "kubernetes_secret" "opsdb_utility_credential" {
  metadata {
    name      = "opsdb-utility-credential"
    namespace = kubernetes_namespace.utility.metadata[0].name
  }

  type = "Opaque"

  data = {
    "username" = "postgres"
    "password" = data.kubernetes_secret.postgres_credential.data["postgres-password"]
    "host"     = "postgres.utility"
    "port"     = "5432"
  }

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [data.kubernetes_secret.postgres_credential]
}

resource "kubernetes_secret" "minio_credential" {
  metadata {
    name      = "minio-credential"
    namespace = kubernetes_namespace.utility.metadata[0].name
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

resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init-scripts"
    namespace = kubernetes_namespace.utility.metadata[0].name
  }

  data = {
    "my_init_script.sh" = file("../helm_charts/postgres/postgres-init.sql")
  }
}

resource "helm_release" "metadata" {

  name = "metadata-service"

  repository = "https://pilotdataplatform.github.io/helm-charts/"
  chart      = "metadata-service"
  version    = var.metadata_chart_version
  namespace  = kubernetes_namespace.utility.metadata[0].name
  timeout    = "300"

  values = [file("../helm_charts/pilot-hdc/metadata/values.yaml")]

  set {
    name  = "image.tag"
    value = var.metadata_app_version
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_registry.metadata[0].name
  }

  depends_on = [
    helm_release.postgres,
    kubernetes_secret.rsa_public_key
  ]
}


resource "helm_release" "postgres" {

  name = "postgres"

  repository = "https://pilotdataplatform.github.io/helm-charts/"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.utility.metadata[0].name
  version    = var.postgres_chart_version
  timeout    = "300"

  values = [file("../helm_charts/postgres/values.yaml")]

  set {
    name  = "image.tag"
    value = var.postgres_app_version
  }

  set {
    name  = "global.imagePullSecrets[0]"
    value = kubernetes_secret.docker_registry_external.metadata[0].name
  }

  depends_on = [
    kubernetes_config_map.postgres_init
  ]
}

resource "helm_release" "kafka" {

  name = "kafka"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  namespace  = kubernetes_namespace.utility.metadata[0].name
  timeout    = "300"
  # according to this issue we should set the wait to false https://github.com/hashicorp/terraform-provider-helm/issues/683
  wait    = "false"
  version = var.kafka_chart_version

  values = [file("../helm_charts/kafka/values.yaml")]
  depends_on = [
    kubernetes_manifest.configmap_utility_kafka_plugin_downloader
  ]

}

resource "kubernetes_manifest" "configmap_utility_kafka_plugin_downloader" {
  manifest = {
    "apiVersion" = "v1"
    "data" = {
      "kafka_plugin_downloader.sh" = <<-EOT
      #!/bin/sh \n cd /tmp \n wget https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-jdbc/versions/10.3.3/confluentinc-kafka-connect-jdbc-10.3.3.zip \n wget  https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-elasticsearch/versions/11.1.8/confluentinc-kafka-connect-elasticsearch-11.1.8.zip \n unzip confluentinc-kafka-connect-jdbc-10.3.3.zip \n unzip confluentinc-kafka-connect-elasticsearch-11.1.8.zip \n rm confluentinc-kafka-connect-jdbc-10.3.3.zip \n rm confluentinc-kafka-connect-elasticsearch-11.1.8.zip \n
      EOT
    }
    "kind" = "ConfigMap"
    "metadata" = {
      "name"      = "kafka-plugin-downloader"
      "namespace" = "utility"
    }
  }
}

resource "helm_release" "project" {

  name = "project-service"

  repository = "https://pilotdataplatform.github.io/helm-charts/"
  chart      = "project-service"
  version    = var.project_chart_version
  namespace  = kubernetes_namespace.utility.metadata[0].name
  timeout    = "300"

  values = [file("../helm_charts/pilot-hdc/project/values.yaml")]

  set {
    name  = "image.tag"
    value = var.project_app_version
  }

  set {
    name  = "imagePullSecrets[0].name"
    value = kubernetes_secret.docker_registry.metadata[0].name
  }

  depends_on = [
    helm_release.postgres,
    kubernetes_secret.opsdb_utility_credential,
    kubernetes_secret.minio_credential
  ]
}
