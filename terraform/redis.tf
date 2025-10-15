# Redis namespace for dataops service dependency
resource "kubernetes_namespace" "redis" {
  metadata {
    name = "redis"
  }
}

# Docker registry pull secret for redis namespace
resource "kubernetes_secret" "docker_registry_external_redis" {
  metadata {
    name      = "docker-registry-external-secret"
    namespace = kubernetes_namespace.redis.metadata[0].name
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

# Redis Helm release - master-only deployment
resource "helm_release" "redis" {
  name             = "redis"
  repository       = "https://pilotdataplatform.github.io/helm-charts/"
  chart            = "redis"
  namespace        = kubernetes_namespace.redis.metadata[0].name
  create_namespace = "false"
  timeout          = "300"
  version          = var.redis_chart_version

  values = [file("../helm_charts/redis/values.yaml")]

  depends_on = [
    kubernetes_namespace.redis,
    kubernetes_secret.docker_registry_external_redis
  ]
}

# Read auto-generated Redis password from Bitnami chart
data "kubernetes_secret" "redis_credential" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.redis.metadata[0].name
  }
  depends_on = [helm_release.redis]
}
