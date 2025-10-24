# Keycloak Client Configuration for Auth Service
# Uses Terraform Keycloak provider to manage OIDC client declaratively
# Note: Admin credentials are provided via variables (keycloak_admin_username/password)

# Create OIDC client for pilot-hdc-lite auth service
resource "keycloak_openid_client" "pilot_hdc_lite" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "pilot-hdc-lite"

  name    = "Pilot HDC Lite Auth Service"
  enabled = true

  # Confidential client - generates client secret
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  service_accounts_enabled     = true

  # Valid redirect URIs - HTTPS only
  valid_redirect_uris = [
    "https://${var.external_ip}.nip.io/*"
  ]

  # Web origins - HTTPS only
  web_origins = [
    "https://${var.external_ip}.nip.io"
  ]

  # Service URLs - HTTPS only
  root_url  = "https://${var.external_ip}.nip.io"
  admin_url = "https://${var.external_ip}.nip.io"
  base_url  = "https://${var.external_ip}.nip.io"

  backchannel_logout_session_required = false
}

# Configure default scopes for the client
resource "keycloak_openid_client_default_scopes" "pilot_hdc_lite" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.pilot_hdc_lite.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "openid"
  ]
}

# Output the client secret for use in auth service configuration
# This will be consumed by the auth-utility-secret
output "keycloak_client_secret" {
  value     = keycloak_openid_client.pilot_hdc_lite.client_secret
  sensitive = true
}

output "keycloak_client_id" {
  value = keycloak_openid_client.pilot_hdc_lite.client_id
}
