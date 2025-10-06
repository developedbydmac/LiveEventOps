#!/bin/bash

# Azure Monitor Webhook Setup Script
# This script configures Azure Monitor action groups to trigger GitHub Actions workflows

set -e

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-liveeventops-rg}"
ACTION_GROUP_NAME="liveeventops-incident-response"
WEBHOOK_NAME="github-actions-webhook"

# GitHub configuration (to be set by user)
GITHUB_OWNER=""
GITHUB_REPO=""
GITHUB_TOKEN=""

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
Usage: ./setup-webhook.sh [OPTIONS]

Configure Azure Monitor to trigger GitHub Actions incident response workflow

OPTIONS:
    -g, --resource-group    Azure resource group name
    -o, --github-owner      GitHub repository owner/organization
    -r, --github-repo       GitHub repository name
    -t, --github-token      GitHub personal access token (with repo scope)
    -h, --help              Show this help message

EXAMPLES:
    # Basic setup
    ./setup-webhook.sh -o myorg -r liveeventops -t ghp_xxxxxxxxxxxx

    # With custom resource group
    ./setup-webhook.sh -g custom-rg -o myorg -r liveeventops -t ghp_xxxxxxxxxxxx

ENVIRONMENT VARIABLES:
    AZURE_RESOURCE_GROUP    Default resource group name
    GITHUB_OWNER           Default GitHub owner
    GITHUB_REPO            Default GitHub repository
    GITHUB_TOKEN           Default GitHub token

PREREQUISITES:
    1. Azure CLI installed and logged in
    2. GitHub personal access token with 'repo' scope
    3. Repository with incident-response.yml workflow
    4. Azure Monitor action group already exists (from Terraform)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -o|--github-owner)
                GITHUB_OWNER="$2"
                shift 2
                ;;
            -r|--github-repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -t|--github-token)
                GITHUB_TOKEN="$2"
                shift 2
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

    # Use environment variables as defaults
    GITHUB_OWNER=${GITHUB_OWNER:-$GITHUB_OWNER}
    GITHUB_REPO=${GITHUB_REPO:-$GITHUB_REPO}
    GITHUB_TOKEN=${GITHUB_TOKEN:-$GITHUB_TOKEN}
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

    # Check required parameters
    if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        error "GitHub owner, repository, and token are required"
        show_help
        exit 1
    fi

    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        error "Resource group '$RESOURCE_GROUP' does not exist"
        exit 1
    fi

    # Check if action group exists
    if ! az monitor action-group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACTION_GROUP_NAME" &> /dev/null; then
        error "Action group '$ACTION_GROUP_NAME' does not exist. Run Terraform first."
        exit 1
    fi

    success "Prerequisites validated"
}

create_webhook_url() {
    log "Creating GitHub webhook URL..."

    # GitHub repository dispatch webhook URL
    WEBHOOK_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/dispatches"
    
    log "Webhook URL: $WEBHOOK_URL"
    
    # Test webhook accessibility
    if curl -s -f -H "Authorization: token $GITHUB_TOKEN" "$WEBHOOK_URL" &> /dev/null; then
        success "GitHub API accessible"
    else
        warning "Cannot verify GitHub API access. Please check token permissions."
    fi
}

update_action_group() {
    log "Updating Azure Monitor action group with webhook..."

    # Get current action group configuration
    local current_config=$(az monitor action-group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACTION_GROUP_NAME" \
        --output json)

    # Extract current webhooks
    local current_webhooks=$(echo "$current_config" | jq -r '.webhookReceivers // []')

    # Create new webhook configuration
    local webhook_config=$(cat << EOF
{
    "name": "$WEBHOOK_NAME",
    "serviceUri": "$WEBHOOK_URL",
    "useCommonAlertSchema": true
}
EOF
)

    # Merge with existing webhooks (remove if exists, then add)
    local updated_webhooks=$(echo "$current_webhooks" | jq --argjson new "$webhook_config" '
        map(select(.name != $new.name)) + [$new]
    ')

    # Update action group
    az monitor action-group update \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACTION_GROUP_NAME" \
        --add-webhook "$WEBHOOK_NAME" "$WEBHOOK_URL" \
        --output none

    success "Action group updated with webhook"
}

create_test_payload() {
    log "Creating test payload for webhook verification..."

    local test_payload=$(cat << EOF
{
    "event_type": "azure-monitor-alert",
    "client_payload": {
        "schemaId": "azureMonitorCommonAlertSchema",
        "data": {
            "essentials": {
                "alertId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.AlertsManagement/alerts/test-alert",
                "alertRule": "Test CPU Alert",
                "severity": "2",
                "signalType": "Metric",
                "monitorCondition": "Fired",
                "monitoringService": "Platform",
                "alertTargetIDs": [
                    "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/management-vm-test"
                ],
                "originAlertId": "test-alert-id",
                "firedDateTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                "description": "Test alert for webhook configuration"
            },
            "alertContext": {
                "properties": {},
                "conditionType": "SingleResourceMultipleMetricCriteria",
                "condition": {
                    "allOf": [
                        {
                            "metricName": "Percentage CPU",
                            "metricNamespace": "Microsoft.Compute/virtualMachines",
                            "operator": "GreaterThan",
                            "threshold": "80",
                            "timeAggregation": "Average",
                            "metricValue": 85.5
                        }
                    ]
                }
            }
        }
    }
}
EOF
)

    echo "$test_payload" > webhook-test-payload.json
    log "Test payload saved to: webhook-test-payload.json"
}

test_webhook() {
    log "Testing webhook connectivity..."

    if [[ ! -f "webhook-test-payload.json" ]]; then
        error "Test payload file not found"
        return 1
    fi

    # Test GitHub API endpoint
    local response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d @webhook-test-payload.json \
        "$WEBHOOK_URL")

    local status_code="${response: -3}"
    
    if [[ "$status_code" == "204" ]]; then
        success "Webhook test successful!"
        log "Check your GitHub repository's Actions tab for the triggered workflow"
    else
        error "Webhook test failed with status: $status_code"
        log "Response: ${response%???}"
        return 1
    fi
}

generate_configuration_summary() {
    log "Generating configuration summary..."

    cat > webhook-configuration-summary.md << EOF
# Azure Monitor Webhook Configuration Summary

**Generated:** $(date)
**Resource Group:** $RESOURCE_GROUP
**Action Group:** $ACTION_GROUP_NAME

## Configuration Details

### Webhook Settings
- **Name:** $WEBHOOK_NAME
- **URL:** $WEBHOOK_URL
- **Repository:** $GITHUB_OWNER/$GITHUB_REPO
- **Common Alert Schema:** Enabled

### GitHub Repository Requirements
- Repository must contain \`.github/workflows/incident-response.yml\`
- GitHub token must have \`repo\` scope
- Repository dispatch events must be enabled

### Alert Flow
1. Azure Monitor detects threshold breach
2. Alert rule triggers action group
3. Action group sends webhook to GitHub API
4. GitHub triggers incident-response workflow
5. Workflow runs diagnostics and creates incident report

### Test Command
To manually test the webhook:
\`\`\`bash
curl -X POST \\
  -H "Accept: application/vnd.github.v3+json" \\
  -H "Authorization: token YOUR_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d @webhook-test-payload.json \\
  "$WEBHOOK_URL"
\`\`\`

### Environment Variables for GitHub Actions
Add these secrets to your GitHub repository:
- \`AZURE_CLIENT_ID\`: Azure service principal client ID
- \`AZURE_TENANT_ID\`: Azure tenant ID  
- \`AZURE_SUBSCRIPTION_ID\`: Azure subscription ID
- \`WEBHOOK_URL\`: Optional notification webhook URL

### Next Steps
1. ✅ Webhook configured in Azure Monitor
2. ✅ Test payload created
3. ⚠️  Configure GitHub repository secrets
4. ⚠️  Test end-to-end alert flow
5. ⚠️  Monitor workflow execution logs

### Troubleshooting
- Check GitHub Actions logs for failed webhook deliveries
- Verify Azure Monitor action group webhook configuration
- Ensure GitHub token has not expired
- Test webhook manually using provided curl command

EOF

    success "Configuration summary saved to: webhook-configuration-summary.md"
}

main() {
    echo "🔗 Azure Monitor Webhook Setup"
    echo "============================="
    
    parse_args "$@"
    validate_prerequisites
    create_webhook_url
    update_action_group
    create_test_payload
    test_webhook
    generate_configuration_summary
    
    echo ""
    success "Webhook setup completed successfully!"
    echo ""
    log "Next steps:"
    echo "  1. Configure GitHub repository secrets (Azure credentials)"
    echo "  2. Test the incident response workflow manually"
    echo "  3. Trigger a test alert to verify end-to-end flow"
    echo "  4. Review webhook-configuration-summary.md for details"
    echo ""
    log "Test the setup by running:"
    echo "  gh workflow run incident-response.yml -f action=health-check"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
