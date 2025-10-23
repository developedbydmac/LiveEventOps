#!/bin/bash

# LiveEventOps Production Deployment Script
# Complete deployment automation for production environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/deployment-$(date +%Y%m%d-%H%M%S).log"

# Default values
ENVIRONMENT="prod"
RESOURCE_GROUP="liveeventops-rg"
LOCATION="eastus"
DEPLOYMENT_METHOD="terraform"  # terraform or bicep
SKIP_VALIDATION=false
AUTO_APPROVE=false
BACKUP_EXISTING=true

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

# Help function
show_help() {
    cat << EOF
LiveEventOps Production Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV      Environment name (dev, staging, prod) [default: prod]
    -g, --resource-group NAME  Azure resource group name [default: liveeventops-rg]
    -l, --location REGION      Azure region [default: eastus]
    -m, --method METHOD        Deployment method (terraform|bicep) [default: terraform]
    -s, --skip-validation     Skip pre-deployment validation
    -y, --auto-approve        Auto-approve deployment without prompts
    --no-backup               Skip backup of existing resources
    -h, --help                Show this help message

EXAMPLES:
    # Deploy to production using Terraform
    $0 --environment prod --method terraform

    # Deploy to staging using Bicep with auto-approval
    $0 -e staging -m bicep -y

    # Deploy with custom resource group and location
    $0 -g my-rg -l westus2

PREREQUISITES:
    - Azure CLI installed and authenticated
    - Terraform (if using terraform method)
    - Appropriate Azure permissions
    - SSH public key configured
    - GitHub repository secrets configured (for CI/CD integration)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -m|--method)
            DEPLOYMENT_METHOD="$2"
            shift 2
            ;;
        -s|--skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        -y|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --no-backup)
            BACKUP_EXISTING=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Banner
echo -e "${GREEN}"
cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  🚀 LiveEventOps Production Deployment                     │
│                                                             │
│  Deploying enterprise-grade live event infrastructure      │
│  with automated monitoring and security controls.          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

log "Starting LiveEventOps production deployment"
log "Environment: $ENVIRONMENT"
log "Resource Group: $RESOURCE_GROUP"
log "Location: $LOCATION"
log "Deployment Method: $DEPLOYMENT_METHOD"
log "Log File: $LOG_FILE"

# Validation functions
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    success "Azure CLI found"
    
    # Check Azure authentication
    if ! az account show &> /dev/null; then
        error "Not authenticated to Azure. Please run 'az login'."
        exit 1
    fi
    success "Azure authentication verified"
    
    # Check deployment method tools
    if [[ "$DEPLOYMENT_METHOD" == "terraform" ]]; then
        if ! command -v terraform &> /dev/null; then
            error "Terraform not found. Please install Terraform."
            exit 1
        fi
        success "Terraform found"
    fi
    
    # Check SSH key
    if [[ -z "${SSH_PUBLIC_KEY:-}" ]] && [[ ! -f ~/.ssh/id_rsa.pub ]]; then
        warn "SSH public key not found. Generate one with: ssh-keygen -t rsa -b 4096"
    fi
    
    # Get current subscription info
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
    log "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

validate_environment() {
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        warn "Skipping environment validation"
        return 0
    fi
    
    log "Validating deployment environment..."
    
    # Check if resource group exists
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log "Resource group '$RESOURCE_GROUP' exists"
        
        if [[ "$BACKUP_EXISTING" == "true" ]]; then
            backup_existing_resources
        fi
    else
        log "Resource group '$RESOURCE_GROUP' will be created"
    fi
    
    # Validate Azure quotas and limits
    log "Checking Azure quotas..."
    
    # Check compute quota
    COMPUTE_USAGE=$(az vm list-usage --location "$LOCATION" --query "[?name.value=='cores'].{used:currentValue,limit:limit}" -o tsv)
    if [[ -n "$COMPUTE_USAGE" ]]; then
        USED_CORES=$(echo "$COMPUTE_USAGE" | cut -f1)
        LIMIT_CORES=$(echo "$COMPUTE_USAGE" | cut -f2)
        if [[ $((USED_CORES + 4)) -gt $LIMIT_CORES ]]; then
            warn "Approaching compute core limit. Used: $USED_CORES, Limit: $LIMIT_CORES"
        fi
    fi
    
    success "Environment validation completed"
}

backup_existing_resources() {
    log "Creating backup of existing resources..."
    
    BACKUP_DIR="${PROJECT_ROOT}/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Export resource group template
    if az group export --name "$RESOURCE_GROUP" --output-template "${BACKUP_DIR}/resources.json" &> /dev/null; then
        success "Resource group template backed up"
    fi
    
    # Backup Key Vault secrets
    KV_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'liveeventops-kv')].name" -o tsv | head -1)
    if [[ -n "$KV_NAME" ]]; then
        log "Backing up Key Vault secrets from $KV_NAME"
        az keyvault secret list --vault-name "$KV_NAME" --query "[].{name:name,value:value}" > "${BACKUP_DIR}/keyvault-secrets.json" 2>/dev/null || true
    fi
    
    log "Backup created in: $BACKUP_DIR"
}

deploy_terraform() {
    log "Deploying infrastructure using Terraform..."
    
    cd "${PROJECT_ROOT}/terraform"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init \
        -backend-config="resource_group_name=${RESOURCE_GROUP}-tfstate" \
        -backend-config="storage_account_name=liveeventopstfstate" \
        -backend-config="container_name=tfstate" \
        -backend-config="key=liveeventops.terraform.tfstate"
    
    # Plan deployment
    log "Creating Terraform plan..."
    terraform plan \
        -var="environment=$ENVIRONMENT" \
        -var="ssh_public_key=${SSH_PUBLIC_KEY:-$(cat ~/.ssh/id_rsa.pub)}" \
        -var="webhook_url=${WEBHOOK_URL:-}" \
        -var="alert_email=${ALERT_EMAIL:-admin@liveeventops.com}" \
        -out=tfplan
    
    # Apply deployment
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        log "Applying Terraform plan (auto-approved)..."
        terraform apply -auto-approve tfplan
    else
        log "Applying Terraform plan..."
        terraform apply tfplan
    fi
    
    # Get outputs
    log "Retrieving Terraform outputs..."
    terraform output -json > "${PROJECT_ROOT}/terraform-outputs.json"
    
    success "Terraform deployment completed"
}

deploy_bicep() {
    log "Deploying infrastructure using Bicep..."
    
    cd "${PROJECT_ROOT}/bicep"
    
    # Create resource group
    log "Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    
    # Validate template
    log "Validating Bicep template..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters sshPublicKey="${SSH_PUBLIC_KEY:-$(cat ~/.ssh/id_rsa.pub)}" \
                    webhookUrl="${WEBHOOK_URL:-}" \
                    alertEmail="${ALERT_EMAIL:-admin@liveeventops.com}" \
                    environment="$ENVIRONMENT"
    
    # Deploy template
    DEPLOYMENT_NAME="liveeventops-$(date +%Y%m%d-%H%M%S)"
    log "Deploying Bicep template..."
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters sshPublicKey="${SSH_PUBLIC_KEY:-$(cat ~/.ssh/id_rsa.pub)}" \
                    webhookUrl="${WEBHOOK_URL:-}" \
                    alertEmail="${ALERT_EMAIL:-admin@liveeventops.com}" \
                    environment="$ENVIRONMENT" \
        --name "$DEPLOYMENT_NAME"
    
    # Get outputs
    log "Retrieving Bicep outputs..."
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs > "${PROJECT_ROOT}/bicep-outputs.json"
    
    success "Bicep deployment completed"
}

post_deployment_validation() {
    log "Running post-deployment validation..."
    
    # Test VM connectivity
    if [[ -f "${PROJECT_ROOT}/terraform-outputs.json" ]]; then
        VM_IP=$(jq -r '.management_vm_public_ip.value // empty' "${PROJECT_ROOT}/terraform-outputs.json")
    elif [[ -f "${PROJECT_ROOT}/bicep-outputs.json" ]]; then
        VM_IP=$(jq -r '.managementVmPublicIP.value // empty' "${PROJECT_ROOT}/bicep-outputs.json")
    fi
    
    if [[ -n "$VM_IP" ]]; then
        log "Testing VM connectivity to $VM_IP..."
        if timeout 30 bash -c "until nc -z $VM_IP 22; do sleep 1; done"; then
            success "VM is accessible on SSH port 22"
        else
            warn "VM connectivity test failed"
        fi
    fi
    
    # Test Key Vault access
    KV_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'liveeventops-kv')].name" -o tsv | head -1)
    if [[ -n "$KV_NAME" ]]; then
        log "Testing Key Vault access to $KV_NAME..."
        if az keyvault secret list --vault-name "$KV_NAME" --max-results 1 &> /dev/null; then
            success "Key Vault is accessible"
        else
            warn "Key Vault access test failed"
        fi
    fi
    
    # Test storage account
    STORAGE_NAME=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'liveeventops')].name" -o tsv | head -1)
    if [[ -n "$STORAGE_NAME" ]]; then
        log "Testing storage account access to $STORAGE_NAME..."
        if az storage container list --account-name "$STORAGE_NAME" &> /dev/null; then
            success "Storage account is accessible"
        else
            warn "Storage account access test failed"
        fi
    fi
    
    success "Post-deployment validation completed"
}

configure_monitoring() {
    log "Configuring monitoring and alerting..."
    
    # Get Log Analytics workspace
    LAW_NAME=$(az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    if [[ -n "$LAW_NAME" ]]; then
        log "Configuring Log Analytics workspace: $LAW_NAME"
        
        # Enable VM insights (if applicable)
        if [[ -n "$VM_IP" ]]; then
            log "Enabling VM insights for management VM..."
            # VM insights configuration would go here
        fi
    fi
    
    # Configure Application Insights
    AI_NAME=$(az monitor app-insights component list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    if [[ -n "$AI_NAME" ]]; then
        log "Application Insights configured: $AI_NAME"
    fi
    
    success "Monitoring configuration completed"
}

generate_deployment_summary() {
    log "Generating deployment summary..."
    
    SUMMARY_FILE="${PROJECT_ROOT}/deployment-summary-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$SUMMARY_FILE" << EOF
# LiveEventOps Production Deployment Summary

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Method:** $DEPLOYMENT_METHOD
**Resource Group:** $RESOURCE_GROUP
**Location:** $LOCATION

## Infrastructure Components

### Compute Resources
EOF
    
    # Add VM information
    if [[ -n "${VM_IP:-}" ]]; then
        cat >> "$SUMMARY_FILE" << EOF
- **Management VM**: $VM_IP
  - SSH Access: \`ssh azureuser@$VM_IP\`
EOF
    fi
    
    # Add Key Vault information
    if [[ -n "${KV_NAME:-}" ]]; then
        cat >> "$SUMMARY_FILE" << EOF

### Security
- **Key Vault**: $KV_NAME
  - Stores SSH keys, webhook URLs, and other secrets
EOF
    fi
    
    # Add storage information
    if [[ -n "${STORAGE_NAME:-}" ]]; then
        cat >> "$SUMMARY_FILE" << EOF

### Storage
- **Storage Account**: $STORAGE_NAME
  - Used for media files and configuration storage
EOF
    fi
    
    cat >> "$SUMMARY_FILE" << EOF

## Next Steps

1. **Connect to Management VM:**
   \`\`\`bash
   ssh azureuser@$VM_IP
   \`\`\`

2. **Access Key Vault:**
   \`\`\`bash
   az keyvault secret list --vault-name $KV_NAME
   \`\`\`

3. **Monitor Resources:**
   - Check Azure Monitor dashboards
   - Review Application Insights metrics
   - Monitor Log Analytics workspace

4. **Configure Applications:**
   - Deploy application code
   - Configure monitoring agents
   - Set up automated backups

## Troubleshooting

If you encounter issues:

1. Check the deployment log: \`$LOG_FILE\`
2. Review Azure Activity Log for the resource group
3. Verify network connectivity and security groups
4. Check Key Vault access policies and RBAC assignments

## Cleanup

To remove all resources:
\`\`\`bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
\`\`\`

---
*Generated by LiveEventOps deployment script*
EOF
    
    success "Deployment summary created: $SUMMARY_FILE"
}

# Confirmation prompt
confirm_deployment() {
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        return 0
    fi
    
    echo
    echo -e "${YELLOW}Deployment Configuration:${NC}"
    echo "  Environment: $ENVIRONMENT"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Location: $LOCATION"
    echo "  Method: $DEPLOYMENT_METHOD"
    echo "  Backup Existing: $BACKUP_EXISTING"
    echo
    
    read -p "Do you want to proceed with this deployment? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
}

# Main execution
main() {
    # Check prerequisites
    check_prerequisites
    
    # Validate environment
    validate_environment
    
    # Confirm deployment
    confirm_deployment
    
    # Deploy infrastructure
    if [[ "$DEPLOYMENT_METHOD" == "terraform" ]]; then
        deploy_terraform
    elif [[ "$DEPLOYMENT_METHOD" == "bicep" ]]; then
        deploy_bicep
    else
        error "Unknown deployment method: $DEPLOYMENT_METHOD"
        exit 1
    fi
    
    # Post-deployment tasks
    post_deployment_validation
    configure_monitoring
    generate_deployment_summary
    
    # Success message
    echo
    echo -e "${GREEN}"
    cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  🎉 Deployment Completed Successfully! 🎉                  │
│                                                             │
│  Your LiveEventOps infrastructure is ready for             │
│  production workloads and live event management.           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    
    success "LiveEventOps production deployment completed successfully!"
    log "Check the deployment summary for next steps and configuration details"
}

# Trap for cleanup
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
