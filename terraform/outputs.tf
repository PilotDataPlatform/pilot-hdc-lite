output "cluster_info" {
  description = "Cluster access information"
  value = {
    node_ip      = local.node_ip
    nodeport     = var.nodeport
    platform_url = "https://${local.node_ip}:${var.nodeport}"
    keycloak_url = "https://keycloak.${local.node_ip}.nip.io:${var.nodeport}"
    minio_url    = "https://minio.${local.node_ip}.nip.io:${var.nodeport}"
    vault_url    = var.deploy_vault ? (var.debug_mode ? "https://vault.${local.node_ip}.nip.io:${var.nodeport}" : "Internal only - use kubectl port-forward") : "Vault not deployed"
  }
}

output "service_access" {
  description = "Service access information"
  value = {
    urls = merge({
      keycloak      = "https://keycloak.${local.node_ip}.nip.io"
      minio_console = "https://minio-console.${local.node_ip}.nip.io"
      minio_api     = "https://minio-api.${local.node_ip}.nip.io"
      }, var.deploy_vault ? (var.debug_mode ? {
        vault = "https://vault.${local.node_ip}.nip.io"
        } : {
        vault_access = "kubectl port-forward svc/vault -n vault 8200:8200"
      }) : {
      vault_status = "Vault not deployed"
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
    vault_access = var.deploy_vault ? {
      note                = var.debug_mode ? "Vault UI accessible externally (DEBUG MODE ONLY)" : "Vault access for security - internal only"
      debug_mode_enabled  = var.debug_mode
      deployment_disabled = false
      secure_access_commands = [
        "kubectl port-forward svc/vault -n vault 8200:8200  # Access via http://localhost:8200",
        "kubectl exec -n vault deployment/vault -- vault status  # Check vault status",
        "kubectl exec -n vault deployment/vault -- vault auth -method=token token=root  # Authenticate with root token"
      ]
      } : {
      note                   = "Vault not deployed - set deploy_vault=true to enable"
      debug_mode_enabled     = false
      deployment_disabled    = true
      secure_access_commands = []
    }
  }
}
