#!/bin/bash

# Azure Key Vault Setup Script for LiveEventOps
# This script helps configure Key Vault access and initial secrets

set -e

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-liveeventops-rg}"
KEY_VAULT_NAME=""
SUBSCRIPTION_ID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_help() {
    cat << 'EOF'
Usage: ./setup-key-vault.sh [OPTIONS]

Configure Azure Key Vault for LiveEventOps platform

OPTIONS:
    -g, --resource-group    Azure resource group name
    -k, --key-vault         Key Vault name (auto-detected if not provided)
    -s, --subscription      Azure subscription ID
    -h, --help              Show this help message

COMMANDS:
    setup-access           Configure access policies for service principal
    migrate-secrets        Migrate secrets from GitHub to Key Vault
    verify-access          Test Key Vault access and permissions
    rotate-secrets         Update secrets with new values

EXAMPLES:
    # Auto-detect and setup access
    ./setup-key-vault.sh setup-access

    # Migrate secrets from environment variables
    ./setup-key-vault.sh migrate-secrets

    # Verify current access
    ./setup-key-vault.sh verify-access

ENVIRONMENT VARIABLES:
    AZURE_RESOURCE_GROUP    Default resource group
    SSH_PUBLIC_KEY         SSH public key for migration
    WEBHOOK_URL           Webhook URL for migration
    ALERT_EMAIL           Alert email for migration
EOF
}

parse_args() {
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -k|--key-vault)
                KEY_VAULT_NAME="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            setup-access|migrate-secrets|verify-access|rotate-secrets)
                COMMAND="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        error "Command is required"
        show_help
        exit 1
    fi
}

validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        error "Not logged in to Azure. Run 'az login' first"
        exit 1
    fi
    
    # Set subscription if provided
    if [[ -n "$SUBSCRIPTION_ID" ]]; then
        log "Setting subscription to $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    # Auto-detect Key Vault if not provided
    if [[ -z "$KEY_VAULT_NAME" ]]; then
        log "Auto-detecting Key Vault in resource group: $RESOURCE_GROUP"
        KEY_VAULT_NAME=$(az keyvault list \
            --resource-group "$RESOURCE_GROUP" \
            --query "[?starts_with(name, 'liveeventops-kv')].name" \
            -o tsv | head -1)
        
        if [[ -z "$KEY_VAULT_NAME" ]]; then
            error "No Key Vault found in resource group: $RESOURCE_GROUP"
            error "Please deploy infrastructure first or specify Key Vault name with -k"
            exit 1
        fi
        
        log "Found Key Vault: $KEY_VAULT_NAME"
    fi
    
    success "Prerequisites validated"
}

setup_access() {
    log "Setting up Key Vault access policies..."
    
    # Get current user object ID
    CURRENT_USER_ID=$(az ad signed-in-user show --query objectId -o tsv)
    log "Current user object ID: $CURRENT_USER_ID"
    
    # Set access policy for current user
    log "Granting Key Vault access to current user..."
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --object-id "$CURRENT_USER_ID" \
        --secret-permissions get list set delete recover backup restore purge \
        --key-permissions get list create delete update import backup restore recover \
        --certificate-permissions get list create delete update import
    
    success "Access policy configured for current user"
    
    # Check if service principal exists and grant access
    if [[ -n "${AZURE_CLIENT_ID:-}" ]]; then
        log "Setting up access for service principal: $AZURE_CLIENT_ID"
        
        az keyvault set-policy \
            --name "$KEY_VAULT_NAME" \
            --spn "$AZURE_CLIENT_ID" \
            --secret-permissions get list set delete recover backup restore \
            --key-permissions get list create delete update import backup restore recover \
            --certificate-permissions get list create delete update import
        
        success "Access policy configured for service principal"
    else
        warning "AZURE_CLIENT_ID not set. Service principal access not configured."
        log "To configure service principal access later:"
        log "  az keyvault set-policy --name $KEY_VAULT_NAME --spn YOUR_CLIENT_ID --secret-permissions get list set"
    fi
}

migrate_secrets() {
    log "Migrating secrets to Key Vault..."
    
    # Migrate SSH public key
    if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
        log "Migrating SSH public key..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "ssh-public-key" \
            --value "$SSH_PUBLIC_KEY" \
            --tags purpose=vm-authentication source=migration
        success "SSH public key migrated"
    else
        warning "SSH_PUBLIC_KEY environment variable not set"
    fi
    
    # Migrate webhook URL
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        log "Migrating webhook URL..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "monitoring-webhook-url" \
            --value "$WEBHOOK_URL" \
            --tags purpose=monitoring-integration source=migration
        success "Webhook URL migrated"
    else
        warning "WEBHOOK_URL environment variable not set"
    fi
    
    # Migrate alert email
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        log "Migrating alert email..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "monitoring-alert-email" \
            --value "$ALERT_EMAIL" \
            --tags purpose=monitoring-alerts source=migration
        success "Alert email migrated"
    else
        # Set default if not provided
        log "Setting default alert email..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "monitoring-alert-email" \
            --value "admin@liveeventops.com" \
            --tags purpose=monitoring-alerts source=default
        success "Default alert email set"
    fi
    
    # Migrate VM admin username (if available)
    if [[ -n "${VM_ADMIN_USERNAME:-}" ]]; then
        log "Migrating VM admin username..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "vm-admin-username" \
            --value "$VM_ADMIN_USERNAME" \
            --tags purpose=vm-authentication source=migration
        success "VM admin username migrated"
    else
        # Set default
        log "Setting default VM admin username..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "vm-admin-username" \
            --value "azureuser" \
            --tags purpose=vm-authentication source=default
        success "Default VM admin username set"
    fi
}

verify_access() {
    log "Verifying Key Vault access..."
    
    # Test list secrets permission
    log "Testing secret list access..."
    if az keyvault secret list --vault-name "$KEY_VAULT_NAME" &> /dev/null; then
        success "✓ Can list secrets"
    else
        error "✗ Cannot list secrets"
        return 1
    fi
    
    # Test get secret permission (if secrets exist)
    log "Testing secret read access..."
    SECRET_NAME=$(az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$SECRET_NAME" ]]; then
        if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$SECRET_NAME" &> /dev/null; then
            success "✓ Can read secrets"
        else
            error "✗ Cannot read secrets"
            return 1
        fi
    else
        warning "No secrets found to test read access"
    fi
    
    # Test set secret permission
    log "Testing secret write access..."
    TEST_SECRET_NAME="access-test-$(date +%s)"
    if az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$TEST_SECRET_NAME" \
        --value "test-value" &> /dev/null; then
        success "✓ Can write secrets"
        
        # Clean up test secret
        az keyvault secret delete --vault-name "$KEY_VAULT_NAME" --name "$TEST_SECRET_NAME" &> /dev/null || true
    else
        error "✗ Cannot write secrets"
        return 1
    fi
    
    success "All access tests passed"
}

rotate_secrets() {
    log "Rotating secrets in Key Vault..."
    
    # Rotate SSH key if new one provided
    if [[ -n "${NEW_SSH_PUBLIC_KEY:-}" ]]; then
        log "Rotating SSH public key..."
        
        # Backup current key
        CURRENT_KEY=$(az keyvault secret show \
            --vault-name "$KEY_VAULT_NAME" \
            --name "ssh-public-key" \
            --query "value" -o tsv 2>/dev/null || echo "")
        
        if [[ -n "$CURRENT_KEY" ]]; then
            az keyvault secret set \
                --vault-name "$KEY_VAULT_NAME" \
                --name "ssh-public-key-backup-$(date +%Y%m%d)" \
                --value "$CURRENT_KEY" \
                --tags purpose=backup source=rotation
        fi
        
        # Set new key
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "ssh-public-key" \
            --value "$NEW_SSH_PUBLIC_KEY" \
            --tags purpose=vm-authentication source=rotation
        
        success "SSH public key rotated"
    else
        warning "NEW_SSH_PUBLIC_KEY environment variable not set"
    fi
    
    # Update webhook URL if new one provided
    if [[ -n "${NEW_WEBHOOK_URL:-}" ]]; then
        log "Updating webhook URL..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "monitoring-webhook-url" \
            --value "$NEW_WEBHOOK_URL" \
            --tags purpose=monitoring-integration source=rotation
        success "Webhook URL updated"
    fi
    
    # Update alert email if new one provided
    if [[ -n "${NEW_ALERT_EMAIL:-}" ]]; then
        log "Updating alert email..."
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "monitoring-alert-email" \
            --value "$NEW_ALERT_EMAIL" \
            --tags purpose=monitoring-alerts source=rotation
        success "Alert email updated"
    fi
}

display_summary() {
    echo ""
    echo "🔐 Key Vault Configuration Summary"
    echo "=================================="
    echo ""
    log "Key Vault: $KEY_VAULT_NAME"
    log "Resource Group: $RESOURCE_GROUP"
    echo ""
    
    # List current secrets
    log "Current secrets:"
    az keyvault secret list \
        --vault-name "$KEY_VAULT_NAME" \
        --query "[].{Name:name, Created:attributes.created, Updated:attributes.updated}" \
        --output table 2>/dev/null || echo "  Unable to list secrets"
    
    echo ""
    log "Next steps:"
    echo "  1. Update GitHub repository secrets with Azure service principal credentials"
    echo "  2. Test GitHub Actions workflow with Key Vault integration"
    echo "  3. Verify secret access in deployed applications"
    echo "  4. Review Key Vault access policies and network settings"
    echo ""
    success "Key Vault setup completed!"
}

main() {
    echo "🔐 Azure Key Vault Setup for LiveEventOps"
    echo "========================================"
    echo ""
    
    parse_args "$@"
    validate_prerequisites
    
    case $COMMAND in
        "setup-access")
            setup_access
            ;;
        "migrate-secrets")
            migrate_secrets
            ;;
        "verify-access")
            verify_access
            ;;
        "rotate-secrets")
            rotate_secrets
            ;;
        *)
            error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
    
    display_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
