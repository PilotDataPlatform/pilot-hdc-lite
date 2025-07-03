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

