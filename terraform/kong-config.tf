# ==============================================================================
# Kong API Gateway Configuration
# ==============================================================================
# Configures Kong services, routes, and plugins for pilot-hdc-lite portal
# Based on production config: cscs-infra/configurations/kong-terraform/
#
# Alpha simplifications:
# - Only portal routes (no upload/download/CLI)
# - Single CORS origin (wildcard)
# - No auth on Kong admin API

# ==============================================================================
# Kong Services - Backend Target Definitions
# ==============================================================================

resource "kong_service" "pilot_portal_api" {
  name            = "pilot-portal-api"
  protocol        = "http"
  host            = "bff.utility"
  port            = 5060
  retries         = 5
  connect_timeout = 60000
  write_timeout   = 60000
  read_timeout    = 60000

  depends_on = [helm_release.kong, helm_release.bff]
}

resource "kong_service" "pilot_user_auth" {
  name            = "pilot-user-auth"
  protocol        = "http"
  host            = "auth.utility"
  port            = 5061
  path            = "/v1/users/auth"
  retries         = 5
  connect_timeout = 60000
  write_timeout   = 60000
  read_timeout    = 60000

  depends_on = [helm_release.kong, helm_release.auth]
}

resource "kong_service" "pilot_user_auth_refresh" {
  name            = "pilot-user-auth-refresh"
  protocol        = "http"
  host            = "auth.utility"
  port            = 5061
  path            = "/v1/users/refresh"
  retries         = 5
  connect_timeout = 60000
  write_timeout   = 60000
  read_timeout    = 60000

  depends_on = [helm_release.kong, helm_release.auth]
}

# ==============================================================================
# Kong Routes - URL Path Mappings
# ==============================================================================

resource "kong_route" "pilot_portal_api" {
  name                       = "pilot-portal-api"
  protocols                  = ["http", "https"]
  methods                    = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
  paths                      = ["/pilot/portal"]
  path_handling              = "v1"
  https_redirect_status_code = 426
  strip_path                 = true   # /pilot/portal/foo → /foo to backend
  preserve_host              = false
  regex_priority             = 0
  service_id                 = kong_service.pilot_portal_api.id
}

resource "kong_route" "pilot_user_auth" {
  name                       = "pilot-user-auth"
  protocols                  = ["http", "https"]
  methods                    = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  paths                      = ["/pilot/portal/users/auth"]
  path_handling              = "v1"
  https_redirect_status_code = 426
  strip_path                 = true
  preserve_host              = false
  regex_priority             = 0
  service_id                 = kong_service.pilot_user_auth.id
}

resource "kong_route" "pilot_user_auth_refresh" {
  name                       = "pilot-user-auth-refresh"
  protocols                  = ["http", "https"]
  methods                    = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  paths                      = ["/pilot/portal/users/refresh"]
  path_handling              = "v1"
  https_redirect_status_code = 426
  strip_path                 = true
  preserve_host              = false
  regex_priority             = 0
  service_id                 = kong_service.pilot_user_auth_refresh.id
}

# ==============================================================================
# Kong Plugins - OIDC Authentication
# ==============================================================================

# OIDC plugin for portal API route
# Validates bearer tokens via Keycloak token introspection
resource "kong_plugin" "pilot_portal_api_oidc" {
  name     = "oidc"
  route_id = kong_route.pilot_portal_api.id
  enabled  = true

  config_json = jsonencode({
    introspection_endpoint_auth_method = null
    redirect_uri_path                  = null
    response_type                      = "code"
    token_endpoint_auth_method         = "client_secret_post"
    logout_path                        = "/logout"
    redirect_after_logout_uri          = "/"
    ssl_verify                         = "no"  # Self-signed certificates
    session_secret                     = null
    introspection_endpoint             = "https://keycloak.${var.external_ip}/realms/hdc/protocol/openid-connect/token/introspect"
    recovery_page_path                 = null
    filters                            = null
    client_id                          = "kong"
    realm                              = "kong"
    discovery                          = "https://keycloak.${var.external_ip}/realms/hdc/.well-known/openid-configuration"
    bearer_only                        = "yes"
    client_secret                      = keycloak_openid_client.kong.client_secret
    scope                              = "openid"
  })
}

# ==============================================================================
# Kong Plugins - CORS
# ==============================================================================

resource "kong_plugin" "pilot_portal_api_cors" {
  name     = "cors"
  route_id = kong_route.pilot_portal_api.id
  enabled  = true

  config_json = jsonencode({
    preflight_continue = false
    credentials        = false
    headers            = []
    methods            = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    exposed_headers    = null
    origins            = ["*"]  # Alpha: wildcard (matches production)
    max_age            = null
  })
}

resource "kong_plugin" "pilot_user_auth_cors" {
  name     = "cors"
  route_id = kong_route.pilot_user_auth.id
  enabled  = true

  config_json = jsonencode({
    preflight_continue = false
    credentials        = false
    headers            = null
    methods            = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD", "TRACE", "CONNECT"]
    exposed_headers    = null
    origins            = ["*"]  # Alpha: wildcard (matches production)
    max_age            = null
  })
}

resource "kong_plugin" "pilot_user_auth_refresh_cors" {
  name     = "cors"
  route_id = kong_route.pilot_user_auth_refresh.id
  enabled  = true

  config_json = jsonencode({
    preflight_continue = false
    credentials        = false
    headers            = null
    methods            = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD", "TRACE", "CONNECT"]
    exposed_headers    = null
    origins            = ["*"]  # Alpha: wildcard (matches production)
    max_age            = null
  })
}
