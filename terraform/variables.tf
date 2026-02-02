variable "nodeport" {
  description = "NodePort for external access"
  type        = number
  default     = 32443
}

variable "external_ip" {
  description = "External IP address for ingress hostnames"
  type        = string
}

variable "certmanager_chart_version" {
  type    = string
  default = "v1.8.0"
}

variable "keycloak_chart_version" {
  type    = string
  default = "13.2.0"
}

variable "keycloak_postgres_chart_version" {
  type    = string
  default = "15.5.17"
}

variable "minio_chart_version" {
  type    = string
  default = "11.10.26"
}

variable "metadata_chart_version" {
  type    = string
  default = "0.5.1"
}

variable "metadata_app_version" {
  type    = string
  default = "2.2.9"
}

variable "project_chart_version" {
  type    = string
  default = "0.2.1"
}

variable "project_app_version" {
  type    = string
  default = "2.3.9"
}

variable "dataops_chart_version" {
  type    = string
  default = "0.2.1"
}

variable "dataops_app_version" {
  type    = string
  default = "2.5.7"
}

variable "docker_registry_username" {
  type        = string
  description = "Username for docker-registry.ebrains.eu"
  default     = ""
  sensitive   = true
}

variable "docker_registry_password" {
  type        = string
  description = "Password for docker-registry.ebrains.eu"
  default     = ""
  sensitive   = true
}

variable "postgres_chart_version" {
  type    = string
  default = "15.5.17"
}

variable "postgres_app_version" {
  type    = string
  default = "16.3.0-932ab18-pgcron"
}

variable "kafka_chart_version" {
  type    = string
  default = "20.0.3"
}

variable "redis_chart_version" {
  type    = string
  default = "16.11.2"
}

variable "docker_registry_external_username" {
  type        = string
  description = "Username for docker-registry.ebrains.eu hdc-services-external project"
  default     = ""
  sensitive   = true
}

variable "docker_registry_external_password" {
  type        = string
  description = "Password for docker-registry.ebrains.eu hdc-services-external project"
  default     = ""
  sensitive   = true
}

variable "debug_mode" {
  type        = bool
  description = "Enable debug mode - exposes internal services (like Vault) externally. WARNING: Only use for development!"
  default     = false
}

variable "deploy_vault" {
  type        = bool
  description = "Deploy Vault service. Set to false to disable vault deployment (default for alpha)"
  default     = false
}

variable "rsa_public_key" {
  type        = string
  description = "RSA public key for metadata service authentication"
  default     = ""
  sensitive   = true
}

variable "auth_chart_version" {
  type    = string
  default = "0.7.2"
}

variable "auth_app_version" {
  type    = string
  default = "2.2.32"
}

variable "bff_chart_version" {
  type    = string
  default = "1.0.1"
}

variable "bff_app_version" {
  type    = string
  default = "2.2.74"
}

variable "portal_chart_version" {
  type    = string
  default = "2.1.2"
}

variable "portal_app_version" {
  type    = string
  default = "1.6.1-hdc-lite"
}

variable "kong_chart_version" {
  type        = string
  default     = "9.1.8"
  description = "Bitnami Kong Helm chart version"
}

variable "kong_image_tag" {
  type        = string
  default     = "latest"
  description = "Kong with OIDC image tag"
}

variable "kong_postgres_image_tag" {
  type        = string
  default     = "11.16.0-debian-11-r5"
  description = "PostgreSQL image tag for Kong database"
}

variable "keycloak_admin_username" {
  type        = string
  description = "Keycloak admin username (must be explicitly set for security)"
  sensitive   = true
}

variable "keycloak_admin_password" {
  type        = string
  description = "Keycloak admin password (must be explicitly set for security - no default)"
  sensitive   = true
}

variable "keycloak_url" {
  type        = string
  description = "Keycloak URL for Terraform provider (defaults to external nip.io URL)"
  default     = ""
}

variable "demo_mode" {
  type        = bool
  description = "Enable demo mode: Terraform provider accepts self-signed certificates. Set to false to require CA-signed certificates."
  default     = false
}

variable "keycloak_realm_name" {
  type        = string
  description = "Name of the Keycloak realm for pilot-hdc-lite"
  default     = "hdc"
}

variable "keycloak_admin_test_username" {
  type        = string
  description = "Username for portal test admin user (HDC realm)"
  default     = "testadmin"
  sensitive   = false
}

variable "keycloak_admin_test_password" {
  type        = string
  description = "Password for portal test admin user (HDC realm)"
  sensitive   = true
}
