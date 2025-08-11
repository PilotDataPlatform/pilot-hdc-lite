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
  default = "2.3.7"
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
