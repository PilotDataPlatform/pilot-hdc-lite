## Pilot HDC Lite

A lightweight, single-VM lite version of the [Pilot-HDC](https://hdc.humanbrainproject.eu/) platform. This lite version is designed for:
- Scientific researchers and small labs
- Internal development teams
- CI/CD and demo environments
- Local testing and evaluation

### Key Features
- **One-script deployment**: `./bootstrap.sh` sets up the complete platform
- **Resource efficient**: Runs on 16GB RAM / 4-6 vCPU / 100GB disk
- **Offline capable**: Works without external dependencies after initial setup
- **Production patterns**: Uses same Terraform + Helm deployment as full platform

### Architecture
- **k3s**: Lightweight Kubernetes distribution
- **Keycloak**: User authentication and SSO
- **MinIO**: S3-compatible object storage
- **PostgreSQL**: Metadata and application databases
- **Redis**: Session and cache management
- **Kafka + Elasticsearch**: Data processing pipeline (utility namespace)

### Quick Start

1. **Prerequisites**:
   - Ubuntu/Debian-based VM with sudo access
   - 16GB+ RAM, 4-6 vCPU, 100GB disk
   - Network connectivity for initial image pulls

2. **Create `.env` file**:
   ```bash
   EXTERNAL_IP=192.168.1.100  # Your VM IP
   RSA_PUBLIC_KEY="<your-public-key>"
   DEMO=true  # Required: Set to 'true' to accept self-signed certificates
              # ⚠️ SECURITY: Skips TLS verification during Terraform bootstrap
              # Only use on isolated/trusted networks (dev/demo environments)
              # For production: Configure proper CA-signed certificates and set DEMO=false

   # Keycloak admin console credentials
   KEYCLOAK_ADMIN_USERNAME="myadminuser"  # **CHANGE THIS**
   KEYCLOAK_ADMIN_PASSWORD="SecurePass123"  # **REQUIRED**

   # Portal login credentials
   KEYCLOAK_ADMIN_TEST_USERNAME="testadmin"  # **CHANGE THIS**
   KEYCLOAK_ADMIN_TEST_PASSWORD="PortalPass456"  # **REQUIRED**
   ```

   **⚠️ Security Requirements**:
   - **Keycloak Admin Console** (`https://keycloak.<EXTERNAL_IP>.nip.io`):
     - Username: `KEYCLOAK_ADMIN_USERNAME` (do NOT use 'admin' or 'user')
     - Password: `KEYCLOAK_ADMIN_PASSWORD` (required - deployment fails if not set)
   - **Portal Login** (`https://<EXTERNAL_IP>.nip.io`):
     - Username: `KEYCLOAK_ADMIN_TEST_USERNAME` (default: 'testadmin')
     - Password: `KEYCLOAK_ADMIN_TEST_PASSWORD` (required - deployment fails if not set)

   **Note**: This platform uses self-signed certificates from cert-manager. You must set `DEMO=true` to allow Terraform to deploy. See [Demo Mode Configuration](#demo-mode-configuration) below.

3. **Deploy**:
   ```bash
   ./bootstrap.sh
   ```

4. **Access**:
   - Keycloak: `https://keycloak.<EXTERNAL_IP>.nip.io`
   - MinIO Console: `https://minio-console.<EXTERNAL_IP>.nip.io`

## Security Considerations

### Demo Mode Configuration

This project uses a `DEMO` environment variable to control Terraform provider behavior during deployment.

#### What DEMO Mode Controls

**DEMO=false (Default - Secure by Default)**
- Terraform provider requires CA-signed certificates
- Use this when you have proper PKI infrastructure
- Deployment will fail with self-signed certificates
- **This is the secure default** - forces explicit security decisions

**DEMO=true (Development with Self-Signed Certificates)**
- Terraform provider accepts self-signed certificates from cert-manager
- **Required for this platform** since it uses cert-manager self-signed certs
- Enables quick setup without needing proper PKI infrastructure
- Explicit opt-in for relaxed TLS verification during deployment
- **NOTE**: User authentication flows always use HTTPS regardless of this setting

#### ✅ What's Always Secured (Regardless of DEMO Mode)

- **HTTPS Everywhere**: All user-facing traffic uses HTTPS via cert-manager
- **Authentication Security**: OAuth2/OIDC flows always use HTTPS endpoints only
- **No HTTP Fallbacks**: HTTP redirects and origins are disabled for auth flows
- **Self-signed Certificates**: Managed by cert-manager ClusterIssuer
- **Secret Management**: Credentials stored in Kubernetes secrets
- **Infrastructure as Code**: Declarative, auditable configuration

#### 🔒 Hardening for Production Use

If deploying this platform for real workloads, implement these additional measures:

1. **Network Isolation**
   - Deploy on isolated private network or VPN
   - Configure firewall rules (allow only 80/443)
   - Use network policies for pod-to-pod isolation

2. **Certificate Management**
   - Replace self-signed certs with CA-signed certificates
   - Use Let's Encrypt for public endpoints
   - Implement proper certificate rotation

3. **Authentication & Authorization**
   - Configure LDAP/Active Directory integration
   - Implement proper RBAC policies
   - Enable audit logging
   - Set up MFA for admin accounts

4. **Data Protection**
   - Enable encryption at rest for persistent volumes
   - Configure backup and disaster recovery
   - Implement data retention policies
   - **Terraform State Security**: The local Terraform state file (`/home/ubuntu/.terraform-state/pilot-hdc-lite.tfstate`) contains sensitive data including database passwords. For production:
     - Use remote state backend (S3, Azure Blob, etc.) with encryption
     - Enable state locking to prevent concurrent modifications
     - Restrict access to state files using IAM policies
     - Never commit state files to version control

5. **Monitoring & Logging**
   - Add Prometheus/Grafana for monitoring
   - Configure centralized logging
   - Set up security alerts

### Reporting Security Issues

This is a demo/development platform. For production deployments, conduct a thorough security review appropriate to your organization's requirements and compliance needs.

## Acknowledgements
The development of the HealthDataCloud open source software was supported by the EBRAINS research infrastructure, funded from the European Union's Horizon 2020 Framework Programme for Research and Innovation under the Specific Grant Agreement No. 945539 (Human Brain Project SGA3) and H2020 Research and Innovation Action Grant Interactive Computing E-Infrastructure for the Human Brain Project ICEI 800858.

This project has received funding from the European Union’s Horizon Europe research and innovation programme under grant agreement No 101058516. Views and opinions expressed are however those of the author(s) only and do not necessarily reflect those of the European Union or other granting authorities. Neither the European Union nor other granting authorities can be held responsible for them.

![EU HDC Acknowledgement](https://hdc.humanbrainproject.eu/img/HDC-EU-acknowledgement.png)
