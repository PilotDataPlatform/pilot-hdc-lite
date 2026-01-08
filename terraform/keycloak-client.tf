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
    "https://${var.external_ip}/*"
  ]

  # Web origins - HTTPS only
  web_origins = [
    "https://${var.external_ip}"
  ]

  # Service URLs - HTTPS only
  root_url  = "https://${var.external_ip}"
  admin_url = "https://${var.external_ip}"
  base_url  = "https://${var.external_ip}"

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
