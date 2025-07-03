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

# Data sources
data "kubernetes_nodes" "cluster_nodes" {}

locals {
  # Use external IP for ingress hostnames
  node_ip = var.external_ip
}
