# Create namespace first
resource "kubernetes_namespace" "vault" {
  count = var.deploy_vault ? 1 : 0
  metadata {
    name = "vault"
  }
}

resource "helm_release" "vault" {
  count = var.deploy_vault ? 1 : 0
  name  = "vault"

  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = kubernetes_namespace.vault[0].metadata[0].name
  create_namespace = false
  timeout          = 300

  values = [file("../helm_charts/vault/values.yaml")]

  depends_on = [helm_release.cert-manager, kubernetes_namespace.vault]
}

# Vault Ingress for external access (only in debug mode for security)
resource "kubernetes_ingress_v1" "vault" {
  count = var.deploy_vault && var.debug_mode ? 1 : 0
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault[0].metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"              = "traefik"
      "cert-manager.io/cluster-issuer"           = "selfsigned-issuer"
      "traefik.ingress.kubernetes.io/router.tls" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["vault.${local.node_ip}.nip.io"]
      secret_name = "vault-tls"
    }

    rule {
      host = "vault.${local.node_ip}.nip.io"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "vault"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.vault]
}

