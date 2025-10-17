#!/bin/bash
# Terraform deployment script with optional auto-approve

set -euo pipefail

# Source .env file for configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
else
    echo "ERROR: Missing .env file. Create one with required variables."
    exit 1
fi

# Export Terraform variables
export TF_VAR_external_ip="${EXTERNAL_IP}"
export TF_VAR_docker_registry_username="${DOCKER_REGISTRY_USERNAME:-}"
export TF_VAR_docker_registry_password="${DOCKER_REGISTRY_PASSWORD:-}"
export TF_VAR_docker_registry_external_username="${DOCKER_REGISTRY_EXTERNAL_USERNAME:-}"
export TF_VAR_docker_registry_external_password="${DOCKER_REGISTRY_EXTERNAL_PASSWORD:-}"
export TF_VAR_rsa_public_key="${RSA_PUBLIC_KEY:-}"
export TF_VAR_demo_mode="${DEMO:-false}"
export TF_VAR_keycloak_admin_username="${KEYCLOAK_ADMIN_USERNAME}"

# Check for auto-approve flag
AUTO_APPROVE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve|-y)
            AUTO_APPROVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--auto-approve|-y]"
            exit 1
            ;;
    esac
done

# Ensure state directory exists
mkdir -p /home/ubuntu/.terraform-state

terraform init
terraform plan -out deploy.tfplan

if [ "$AUTO_APPROVE" = true ]; then
    echo "Auto-approve enabled, applying Terraform plan..."
    terraform apply deploy.tfplan
else
    # Prompt for deployment continuation if not provided
    if [ -z "${yn:-}" ]; then
        read -p "Continue deploying? (y/n) " yn
    fi

    # Apply the plan if confirmation is positive
    if [[ "$yn" =~ ^[yY] ]]; then
        terraform apply deploy.tfplan
    else
        echo "Did not run TF apply, exiting script with success."
        exit 0
    fi
fi
