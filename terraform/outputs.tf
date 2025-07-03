output "cluster_info" {
  description = "Cluster access information"
  value = {
    node_ip      = local.node_ip
    nodeport     = var.nodeport
    platform_url = "https://${local.node_ip}:${var.nodeport}"
    keycloak_url = "https://keycloak.${local.node_ip}.nip.io:${var.nodeport}"
    minio_url    = "https://minio.${local.node_ip}.nip.io:${var.nodeport}"
  }
}

output "service_access" {
  description = "Service access information"
  value = {
    urls = merge({
      keycloak      = "https://keycloak.${local.node_ip}.nip.io"
      minio_console = "https://minio-console.${local.node_ip}.nip.io"
      minio_api     = "https://minio-api.${local.node_ip}.nip.io"
      }, var.debug_mode ? {
      vault = "https://vault.${local.node_ip}.nip.io"
      } : {
      vault_access = "kubectl port-forward svc/vault -n vault 8200:8200"
    })
    credentials = {
      note = "Passwords are auto-generated. Retrieve with kubectl commands below:"
      keycloak = {
        username         = "user"
        password_command = "kubectl get secret keycloak -n keycloak -o jsonpath='{.data.admin-password}' | base64 -d"
      }
      minio = {
        username_command = "kubectl get secret minio -n minio -o jsonpath='{.data.root-user}' | base64 -d"
        password_command = "kubectl get secret minio -n minio -o jsonpath='{.data.root-password}' | base64 -d"
      }
      postgres = {
        username         = "bn_keycloak"
        password_command = "kubectl get secret postgres-postgresql -n keycloak -o jsonpath='{.data.password}' | base64 -d"
      }
    }
  }
}
