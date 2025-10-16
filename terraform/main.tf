terraform {
  backend "local" {
    path = "/home/ubuntu/.terraform-state/pilot-hdc-lite.tfstate"
  }
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }

    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "keycloak" {
  client_id                = "admin-cli"
  username                 = var.keycloak_admin_username
  password                 = data.kubernetes_secret.keycloak_admin.data["admin-password"]
  url                      = var.keycloak_url != "" ? var.keycloak_url : "https://keycloak.${var.external_ip}.nip.io"
  tls_insecure_skip_verify = var.demo_mode  # Only skip TLS verification in demo mode
}

# Data sources
data "kubernetes_nodes" "cluster_nodes" {}

locals {
  # Use external IP for ingress hostnames
  node_ip = var.external_ip
}
