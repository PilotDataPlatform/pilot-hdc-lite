resource "helm_release" "message_bus_greenroom" {

  name = "message-bus-greenroom"

  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "rabbitmq"
  version          = var.message_bus_greenroom_chart_version
  namespace        = kubernetes_namespace.greenroom.metadata[0].name
  create_namespace = false
  timeout          = "300"

  values = [file("../helm_charts/rabbitmq/values.yaml")]

  depends_on = [
    kubernetes_namespace.greenroom,
    kubernetes_secret.docker_registry_external_greenroom,
    kubernetes_secret.message_bus_greenroom_secret,
  ]
}
