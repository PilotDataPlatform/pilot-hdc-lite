# Keycloak HDC Realm Configuration
# Creates dedicated realm for pilot-hdc-lite with react-app public client

# HDC Realm
resource "keycloak_realm" "hdc" {
  realm             = var.keycloak_realm_name
  enabled           = true
  display_name      = "Pilot HDC Lite"
  display_name_html = "<h1>Pilot HDC Lite</h1>"

  login_with_email_allowed = true
  user_managed_access      = true
  reset_password_allowed   = true

  # Simplified security
  security_defenses {
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }
}

# -----------------------------------------------------------------------------
# Realm Roles
# -----------------------------------------------------------------------------

# Get built-in offline_access role
data "keycloak_role" "offline_access" {
  realm_id = keycloak_realm.hdc.id
  name     = "offline_access"
}

# Platform admin role
resource "keycloak_role" "platform_admin" {
  realm_id    = keycloak_realm.hdc.id
  name        = "platform-admin"
  description = "Platform Administrator Role"

  composite_roles = [
    data.keycloak_role.offline_access.id
  ]
}

# Admin role
resource "keycloak_role" "admin_role" {
  realm_id    = keycloak_realm.hdc.id
  name        = "admin-role"
  description = "Administrator Role"

  composite_roles = [
    data.keycloak_role.offline_access.id
  ]
}

# -----------------------------------------------------------------------------
# react-app Client (PUBLIC client for Portal SPA)
# -----------------------------------------------------------------------------

resource "keycloak_openid_client" "react_app" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "react-app"

  name    = "React Portal Application"
  enabled = true

  # PUBLIC client - no client secret for browser-based SPAs
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true

  # Valid redirect URIs - allow all paths on portal domain
  valid_redirect_uris = [
    "https://${var.external_ip}.nip.io/*"
  ]

  # Web origins for CORS
  web_origins = [
    "https://${var.external_ip}.nip.io"
  ]

  # Base URL
  base_url = "https://${var.external_ip}.nip.io"

  backchannel_logout_session_required = false
}

# Configure default scopes for react-app client
resource "keycloak_openid_client_default_scopes" "react_app" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "groups",
    "openid"
  ]
}

# -----------------------------------------------------------------------------
# Protocol Mappers for MinIO Integration
# -----------------------------------------------------------------------------

# MinIO policy mapper - maps user attribute "policy" to token claims
resource "keycloak_openid_user_attribute_protocol_mapper" "react_app_minio_policy" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "minio_policy_mapper"

  user_attribute   = "policy"
  claim_name       = "policy"
  claim_value_type = "String"

  add_to_id_token      = true
  add_to_access_token  = true
  add_to_userinfo      = true
}

# MinIO audience mapper - adds "minio" as custom audience
resource "keycloak_openid_audience_protocol_mapper" "react_app_minio_audience" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "aud_mapper"

  included_custom_audience = "minio"
  add_to_id_token          = false
}

# Client ID session note mapper
resource "keycloak_openid_user_session_note_protocol_mapper" "react_app_client_id" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client ID"

  session_note     = "clientId"
  claim_name       = "clientId"
  claim_value_type = "String"
}

# Client IP address session note mapper
resource "keycloak_openid_user_session_note_protocol_mapper" "react_app_client_ip" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client IP Address"

  session_note     = "clientAddress"
  claim_name       = "clientAddress"
  claim_value_type = "String"
}

# Client host session note mapper
resource "keycloak_openid_user_session_note_protocol_mapper" "react_app_client_host" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client Host"

  session_note     = "clientHost"
  claim_name       = "clientHost"
  claim_value_type = "String"
}

# -----------------------------------------------------------------------------
# Test Admin User
# -----------------------------------------------------------------------------

resource "keycloak_user" "admin" {
  realm_id = keycloak_realm.hdc.id
  username = var.keycloak_admin_test_username

  email          = "${var.keycloak_admin_test_username}@pilot-hdc-lite.local"
  email_verified = true
  enabled        = true

  first_name = "Admin"
  last_name  = "User"

  initial_password {
    value     = var.keycloak_admin_test_password
    temporary = false
  }
}

# Assign platform-admin role to admin user
resource "keycloak_user_roles" "admin_platform_admin" {
  realm_id = keycloak_realm.hdc.id
  user_id  = keycloak_user.admin.id

  role_ids = [
    keycloak_role.platform_admin.id,
    keycloak_role.admin_role.id,
    data.keycloak_role.offline_access.id
  ]
}
