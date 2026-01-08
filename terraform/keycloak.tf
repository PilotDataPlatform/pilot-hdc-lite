resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = "keycloak"
  }
}

resource "helm_release" "keycloak" {

  name = "keycloak"

  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "keycloak"
  namespace        = kubernetes_namespace.keycloak.metadata[0].name
  create_namespace = false
  timeout          = "300"
  version          = var.keycloak_chart_version

  values = [file("../helm_charts/keycloak/values.yaml")]

  # Override values with domain
  set {
    name  = "ingress.hostname"
    value = "keycloak.${local.node_ip}"
  }

  # Set admin credentials from variables (required for security)
  set {
    name  = "auth.adminUser"
    value = var.keycloak_admin_username
  }

  set_sensitive {
    name  = "auth.adminPassword"
    value = var.keycloak_admin_password
  }

  depends_on = [
    helm_release.keycloak_postgres
  ]
}

resource "helm_release" "keycloak_postgres" {

  name = "keycloak-postgres"

  repository       = "https://pilotdataplatform.github.io/helm-charts/"
  chart            = "postgresql"
  namespace        = kubernetes_namespace.keycloak.metadata[0].name
  create_namespace = false
  version          = var.keycloak_postgres_chart_version
  timeout          = "300"

  values = [file("../helm_charts/keycloak/postgres-values.yaml")]

  depends_on = [
    kubernetes_namespace.keycloak
  ]
}
