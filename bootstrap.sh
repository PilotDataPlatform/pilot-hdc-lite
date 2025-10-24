#!/bin/bash
# Bootstrap script for pilot-hdc-lite alpha
# Single-VM research platform with k3s, cert-manager, Keycloak, and MinIO
# Usage: ./bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/bootstrap.log"
ANSIBLE_VERSION="10.7.0"

# Load configuration
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
else
    if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
        echo "ERROR: Missing .env file. Copy .env.example to .env and configure: cp .env.example .env"
    else
        echo "ERROR: Missing .env file. Create one with: EXTERNAL_IP=<your-external-ip> and RSA_PUBLIC_KEY=<your-rsa-public-key>"
    fi
    exit 1
fi

# Validate required variables
if [[ -z "${EXTERNAL_IP}" ]]; then
    echo "ERROR: EXTERNAL_IP must be set in .env file"
    exit 1
fi

if [[ -z "${RSA_PUBLIC_KEY}" ]]; then
    echo "ERROR: RSA_PUBLIC_KEY must be set in .env file"
    exit 1
fi

if [[ -z "${KEYCLOAK_ADMIN_USERNAME}" ]]; then
    echo "ERROR: KEYCLOAK_ADMIN_USERNAME must be set in .env file"
    exit 1
fi

if [[ -z "${KEYCLOAK_ADMIN_PASSWORD}" ]]; then
    echo "ERROR: KEYCLOAK_ADMIN_PASSWORD must be set in .env file"
    echo "SECURITY: This password is required for Keycloak admin console access"
    echo "Please set a strong password in your .env file"
    exit 1
fi

if [[ -z "${KEYCLOAK_ADMIN_TEST_PASSWORD}" ]]; then
    echo "ERROR: KEYCLOAK_ADMIN_TEST_PASSWORD must be set in .env file"
    echo "INFO: This password is for portal login (username: ${KEYCLOAK_ADMIN_TEST_USERNAME:-testadmin})"
    echo "Please set a strong password in your .env file"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

check_requirements() {
    log "Checking system requirements..."
    
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
    
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges. Please ensure your user can run sudo commands."
    fi
    
    # Check system resources
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 14 ]]; then
        warn "System has ${mem_gb}GB RAM. Recommended minimum is 16GB."
    fi
    
    log "System requirements check completed"
}

install_python_and_ansible() {
    log "Installing Python and Ansible..."
    
    # Install system packages based on OS
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y python3 python3-pip python3-venv curl wget jq
    elif command -v yum >/dev/null 2>&1; then
        sudo yum update -y
        sudo DEBIAN_FRONTEND=noninteractive yum install -y python3 python3-pip curl wget jq
    elif command -v pacman >/dev/null 2>&1; then
        sudo DEBIAN_FRONTEND=noninteractive pacman -Sy --noconfirm python python-pip curl wget jq
    else
        error "Unsupported package manager. Please install python3, pip, curl, wget, and jq manually."
    fi
    
    # Create virtual environment for Ansible
    if [[ ! -d "${SCRIPT_DIR}/.venv" ]]; then
        python3 -m venv "${SCRIPT_DIR}/.venv"
    fi
    
    # Activate virtual environment and install Ansible
    source "${SCRIPT_DIR}/.venv/bin/activate"
    pip install --upgrade pip
    pip install "ansible==${ANSIBLE_VERSION}" kubernetes
    
    log "Python and Ansible installation completed"
}

run_ansible() {
    log "Running Ansible playbook..."
    
    # Activate virtual environment
    source "${SCRIPT_DIR}/.venv/bin/activate"
    
    # Run Ansible playbook
    cd "${SCRIPT_DIR}/ansible"
    ansible-playbook -i inventory site.yml
    cd "${SCRIPT_DIR}"
    
    log "Ansible playbook completed"
}

run_terraform() {
    log "Checking for Terraform..."

    if command -v terraform >/dev/null 2>&1; then
        log "Running Terraform deployment with external IP: ${EXTERNAL_IP}..."
        cd "${SCRIPT_DIR}/terraform"

        # Check if this is a fresh deployment (Keycloak doesn't exist yet)
        if ! kubectl get namespace keycloak &>/dev/null 2>&1; then
            log "Fresh deployment detected - deploying Keycloak infrastructure first..."

            # Source .env and export Terraform variables (required for targeted apply)
            source "${SCRIPT_DIR}/.env"
            export TF_VAR_external_ip="${EXTERNAL_IP}"
            export TF_VAR_docker_registry_username="${DOCKER_REGISTRY_USERNAME:-}"
            export TF_VAR_docker_registry_password="${DOCKER_REGISTRY_PASSWORD:-}"
            export TF_VAR_docker_registry_external_username="${DOCKER_REGISTRY_EXTERNAL_USERNAME:-}"
            export TF_VAR_docker_registry_external_password="${DOCKER_REGISTRY_EXTERNAL_PASSWORD:-}"
            export TF_VAR_rsa_public_key="${RSA_PUBLIC_KEY:-}"
            export TF_VAR_demo_mode="${DEMO:-false}"
            export TF_VAR_keycloak_admin_username="${KEYCLOAK_ADMIN_USERNAME}"
            export TF_VAR_keycloak_admin_password="${KEYCLOAK_ADMIN_PASSWORD}"
            export TF_VAR_keycloak_admin_test_username="${KEYCLOAK_ADMIN_TEST_USERNAME:-testadmin}"
            export TF_VAR_keycloak_admin_test_password="${KEYCLOAK_ADMIN_TEST_PASSWORD}"

            terraform init
            terraform apply -auto-approve \
                -target=kubernetes_namespace.keycloak \
                -target=helm_release.keycloak_postgres \
                -target=helm_release.keycloak

            log "Waiting for Keycloak pods to be ready (timeout: 5 minutes)..."
            kubectl wait --for=condition=ready pod \
                -l app.kubernetes.io/name=keycloak \
                -n keycloak \
                --timeout=300s || warn "Keycloak pod readiness check timed out, continuing anyway..."

            # Brief additional wait for service initialization
            log "Waiting for Keycloak service initialization..."
            sleep 10
        fi

        # Run full deployment (will be no-op for Keycloak on fresh, updates on existing)
        log "Running full Terraform deployment..."
        ./run.sh --auto-approve

        cd "${SCRIPT_DIR}"
        log "Terraform deployment completed"
    else
        warn "Terraform not found. Skipping Terraform deployment."
        warn "Services will need to be deployed manually or install Terraform and run:"
        warn "  cd terraform && ./run.sh -var=\"external_ip=${EXTERNAL_IP}\""
    fi
}

show_status() {
    log "Bootstrap process completed!"
    echo ""
    echo "=== Cluster Status ==="
    if command -v kubectl >/dev/null 2>&1; then
        kubectl get nodes
        echo ""
        kubectl get pods --all-namespaces
        echo ""
        
        echo "=== Access Information ==="
        echo "Portal should be accessible at: https://${EXTERNAL_IP}.nip.io"
        echo "Keycloak should be accessible at: https://keycloak.${EXTERNAL_IP}.nip.io"
        echo "MinIO Console should be accessible at: https://minio-console.${EXTERNAL_IP}.nip.io"
        echo "MinIO API should be accessible at: https://minio-api.${EXTERNAL_IP}.nip.io"
        echo "Platform external IP: ${EXTERNAL_IP}"
        echo "(Once all services are deployed and running)"
    else
        echo "kubectl not available - check k3s installation"
    fi
    
    echo ""
    echo "=== Next Steps ==="
    echo "1. Verify all pods are running: kubectl get pods --all-namespaces"
    echo "2. Check service logs if needed: kubectl logs <pod-name> -n <namespace>"
    echo "3. Access the platform in your browser (accept self-signed certificates)"
}

main() {
    log "Starting pilot-hdc-lite bootstrap process..."
    
    check_requirements
    install_python_and_ansible
    run_ansible
    run_terraform
    show_status
    
    log "Bootstrap process completed!"
}

trap 'error "Bootstrap process interrupted"' INT TERM
main
