# Azure Key Vault Integration Guide

This document provides comprehensive guidance on the Azure Key Vault integration in the LiveEventOps platform, including setup, usage, and security best practices.

## 🔐 Overview

The LiveEventOps platform uses Azure Key Vault for secure secret management, replacing hardcoded secrets in CI/CD pipelines and providing centralized access control for sensitive configuration data.

### Key Features

- **Centralized Secret Management**: Store SSH keys, webhook URLs, and monitoring credentials
- **Pipeline Integration**: GitHub Actions workflows automatically retrieve secrets from Key Vault
- **Access Control**: Granular permissions for different users and service principals
- **Audit Trail**: Complete logging of secret access and modifications
- **Soft Delete Protection**: Configurable retention for accidentally deleted secrets

## 🏗️ Architecture

### Key Vault Resources

```terraform
# Main Key Vault resource
azurerm_key_vault.liveeventops
├── SSH public key storage
├── Monitoring webhook URL
├── Alert email configuration
└── VM admin credentials

# Access Policies
azurerm_key_vault_access_policy.terraform_sp (Terraform service principal)
azurerm_key_vault_access_policy.additional[] (Additional users/SPs)
```

### Stored Secrets

| Secret Name | Purpose | Source |
|-------------|---------|--------|
| `vm-admin-username` | VM administrator username | Terraform variable |
| `ssh-public-key` | SSH public key for VM access | GitHub Secrets → Key Vault |
| `monitoring-webhook-url` | GitHub Actions webhook URL | GitHub Secrets → Key Vault |
| `monitoring-alert-email` | Email for monitoring alerts | Configuration variable |

## 🚀 Setup Instructions

### 1. Initial Deployment

The Key Vault is automatically created when you deploy the Terraform configuration:

```bash
# Deploy infrastructure with Key Vault
terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
terraform apply
```

### 2. GitHub Secrets Configuration

Update your GitHub repository secrets to use the new authentication method:

#### Required Secrets (New Method)
```bash
# Service Principal Authentication
AZURE_CLIENT_ID=12345678-1234-1234-1234-123456789012
AZURE_TENANT_ID=87654321-4321-4321-4321-210987654321
AZURE_SUBSCRIPTION_ID=abcdef01-2345-6789-abcd-ef0123456789

# Terraform State Backend
TF_STATE_RESOURCE_GROUP=tfstate-rg
TF_STATE_STORAGE_ACCOUNT=tfstatexxxxxxxx
TF_STATE_CONTAINER=tfstate

# Initial secrets (will be moved to Key Vault)
SSH_PUBLIC_KEY=ssh-rsa AAAAB3NzaC1y...
WEBHOOK_URL=https://your-webhook-url.com
```

#### Deprecated Secrets (Old Method)
```bash
# These can be removed after Key Vault setup
AZURE_CREDENTIALS={"clientId":"...","clientSecret":"..."}
```

### 3. Service Principal Setup

Create a service principal with Key Vault access:

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "liveeventops-pipeline" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"

# Grant Key Vault access
az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --spn "$CLIENT_ID" \
  --secret-permissions get list set delete \
  --key-permissions get list create delete update import \
  --certificate-permissions get list create delete update import
```

## 🔧 Configuration Options

### Terraform Variables

```hcl
# Key Vault configuration
variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention period (7-90 days)"
  type        = number
  default     = 7
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection (recommended for production)"
  type        = bool
  default     = false  # Set to true for production
}

variable "key_vault_network_default_action" {
  description = "Default network access (Allow/Deny)"
  type        = string
  default     = "Allow"  # Set to "Deny" for production with IP allowlists
}

variable "additional_key_vault_access_policies" {
  description = "Additional access policies for users/service principals"
  type = list(object({
    object_id               = string
    secret_permissions      = list(string)
    key_permissions        = list(string)
    certificate_permissions = list(string)
  }))
  default = []
}
```

### Production Configuration Example

```hcl
# terraform.tfvars
key_vault_purge_protection_enabled = true
key_vault_network_default_action   = "Deny"

additional_key_vault_access_policies = [
  {
    object_id = "user-object-id-1"
    secret_permissions = ["Get", "List"]
    key_permissions = ["Get", "List"]
    certificate_permissions = ["Get", "List"]
  },
  {
    object_id = "devops-team-sp-object-id"
    secret_permissions = ["Get", "List", "Set", "Delete"]
    key_permissions = ["Get", "List", "Create", "Delete", "Update"]
    certificate_permissions = ["Get", "List", "Create", "Delete", "Update"]
  }
]
```

## 🔄 CI/CD Pipeline Integration

### GitHub Actions Workflow Flow

```yaml
# The workflow automatically:
1. Authenticates with Azure using service principal
2. Checks for existing Key Vault in resource group
3. Retrieves secrets from Key Vault if available
4. Falls back to GitHub Secrets if Key Vault not found
5. Uses retrieved values in Terraform operations
```

### Key Vault Secret Retrieval

```bash
# Example of how secrets are retrieved in the pipeline
KV_NAME=$(az keyvault list --resource-group "$RG" --query "[?starts_with(name, 'liveeventops-kv')].name" -o tsv | head -1)

if [ -n "$KV_NAME" ]; then
  SSH_KEY=$(az keyvault secret show --vault-name "$KV_NAME" --name "ssh-public-key" --query "value" -o tsv)
  WEBHOOK_URL=$(az keyvault secret show --vault-name "$KV_NAME" --name "monitoring-webhook-url" --query "value" -o tsv)
  ALERT_EMAIL=$(az keyvault secret show --vault-name "$KV_NAME" --name "monitoring-alert-email" --query "value" -o tsv)
fi
```

### Terraform Variable Assignment

```hcl
# Terraform receives variables from Key Vault or GitHub Secrets
terraform plan \
  -var="ssh_public_key=$SSH_KEY" \
  -var="webhook_url=$WEBHOOK_URL" \
  -var="alert_email=$ALERT_EMAIL"
```

## 🔒 Security Best Practices

### Access Control

1. **Principle of Least Privilege**
   ```bash
   # Grant only necessary permissions
   az keyvault set-policy \
     --name "$KV_NAME" \
     --spn "$SP_ID" \
     --secret-permissions get list  # Read-only for most applications
   ```

2. **Separate Access Policies**
   - **Pipeline Service Principal**: Full secret management
   - **Application Service Principals**: Read-only access to specific secrets
   - **Human Users**: Administrative access with MFA

3. **Network Security**
   ```hcl
   # Restrict network access in production
   network_acls {
     default_action = "Deny"
     bypass         = "AzureServices"
     ip_rules       = ["203.0.113.0/24"]  # Office IP range
     virtual_network_subnet_ids = [azurerm_subnet.management.id]
   }
   ```

### Secret Management

1. **Secret Naming Convention**
   ```
   {purpose}-{environment}-{type}
   
   Examples:
   - vm-admin-username
   - monitoring-webhook-url
   - database-connection-string
   - ssl-certificate-password
   ```

2. **Secret Rotation**
   ```bash
   # Regular rotation schedule
   az keyvault secret set \
     --vault-name "$KV_NAME" \
     --name "ssh-public-key" \
     --value "$(cat ~/.ssh/new_key.pub)" \
     --expires "2024-12-31T23:59:59Z"
   ```

3. **Versioning and Backup**
   ```bash
   # Key Vault automatically versions secrets
   az keyvault secret show \
     --vault-name "$KV_NAME" \
     --name "ssh-public-key" \
     --version "previous-version-id"
   ```

### Monitoring and Auditing

1. **Enable Diagnostic Settings**
   ```hcl
   resource "azurerm_monitor_diagnostic_setting" "key_vault" {
     name               = "key-vault-diagnostics"
     target_resource_id = azurerm_key_vault.liveeventops.id
     
     log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops.id
     
     log {
       category = "AuditEvent"
       enabled  = true
     }
   }
   ```

2. **Set Up Alerts**
   ```hcl
   # Alert on secret access failures
   resource "azurerm_monitor_metric_alert" "key_vault_failures" {
     name                = "key-vault-access-failures"
     resource_group_name = azurerm_resource_group.liveeventops.name
     scopes              = [azurerm_key_vault.liveeventops.id]
     
     criteria {
       metric_namespace = "Microsoft.KeyVault/vaults"
       metric_name      = "ServiceApiResult"
       aggregation      = "Count"
       operator         = "GreaterThan"
       threshold        = 5
       
       dimension {
         name     = "ResultType"
         operator = "Include"
         values   = ["Error"]
       }
     }
   }
   ```

## 🛠️ Operations and Maintenance

### Common Operations

#### Add New Secret
```bash
# Add a new secret
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "new-secret-name" \
  --value "secret-value" \
  --tags purpose=authentication environment=prod
```

#### Grant Access to New User
```bash
# Grant read access to a user
az keyvault set-policy \
  --name "$KV_NAME" \
  --upn "user@company.com" \
  --secret-permissions get list
```

#### Backup Key Vault
```bash
# Backup specific secret
az keyvault secret backup \
  --vault-name "$KV_NAME" \
  --name "critical-secret" \
  --file "secret-backup.blob"
```

### Troubleshooting

#### Common Issues

1. **Access Denied Errors**
   ```bash
   # Check access policies
   az keyvault show --name "$KV_NAME" --query "properties.accessPolicies"
   
   # Verify service principal permissions
   az ad sp show --id "$CLIENT_ID" --query "objectId"
   ```

2. **Secret Not Found**
   ```bash
   # List all secrets
   az keyvault secret list --vault-name "$KV_NAME" --query "[].name"
   
   # Check secret versions
   az keyvault secret list-versions --vault-name "$KV_NAME" --name "secret-name"
   ```

3. **Network Access Issues**
   ```bash
   # Check network rules
   az keyvault show --name "$KV_NAME" --query "properties.networkAcls"
   
   # Test connectivity
   nslookup "$KV_NAME.vault.azure.net"
   ```

### Monitoring Queries

#### Log Analytics KQL Queries

```kql
// Secret access patterns
KeyVaultEvent
| where TimeGenerated > ago(24h)
| where OperationName in ("Get", "List")
| summarize Count = count() by CallerIpAddress, identity_claim_upn_s
| order by Count desc

// Failed access attempts
KeyVaultEvent
| where TimeGenerated > ago(24h)
| where ResultSignature == "Forbidden"
| project TimeGenerated, OperationName, CallerIpAddress, identity_claim_upn_s

// Secret modifications
KeyVaultEvent
| where TimeGenerated > ago(7d)
| where OperationName in ("Set", "Delete", "Update")
| project TimeGenerated, OperationName, RequestUri, identity_claim_upn_s
```

## 📚 Migration Guide

### From GitHub Secrets to Key Vault

1. **Phase 1: Dual Storage**
   - Keep secrets in both GitHub and Key Vault
   - Update pipelines to prefer Key Vault values
   - Test thoroughly in non-production

2. **Phase 2: Key Vault Primary**
   - Validate all pipelines work with Key Vault
   - Document Key Vault as primary source
   - Keep GitHub secrets as backup

3. **Phase 3: Remove GitHub Secrets**
   - Remove sensitive secrets from GitHub
   - Keep only Key Vault access credentials in GitHub
   - Update documentation

### Rollback Plan

```bash
# Emergency rollback to GitHub Secrets
# Comment out Key Vault retrieval in pipeline:
# - name: Get Key Vault secrets
#   id: keyvault
#   run: |
#     # Key Vault logic here...

# Revert to direct GitHub secret usage:
terraform plan \
  -var="ssh_public_key=${{ secrets.SSH_PUBLIC_KEY }}" \
  -var="webhook_url=${{ secrets.WEBHOOK_URL }}"
```

## 🚀 Future Enhancements

### Planned Features

1. **Automatic Secret Rotation**
   ```hcl
   # Planned: Automatic SSH key rotation
   resource "azurerm_key_vault_secret" "ssh_key_rotation" {
     name         = "ssh-public-key"
     key_vault_id = azurerm_key_vault.liveeventops.id
     
     expiration_date = "2024-12-31T23:59:59Z"
     
     # Automatic rotation logic (future)
     rotation_policy {
       automatic {
         time_before_expiry = "P30D"
       }
     }
   }
   ```

2. **Certificate Management**
   ```hcl
   # Planned: SSL certificate storage
   resource "azurerm_key_vault_certificate" "webapp_ssl" {
     name         = "webapp-ssl-cert"
     key_vault_id = azurerm_key_vault.liveeventops.id
     
     certificate_policy {
       issuer_parameters {
         name = "Self"
       }
       
       key_properties {
         exportable = true
         key_size   = 2048
         key_type   = "RSA"
         reuse_key  = true
       }
     }
   }
   ```

3. **Multi-Environment Support**
   ```hcl
   # Planned: Environment-specific Key Vaults
   resource "azurerm_key_vault" "environment" {
     for_each = toset(["dev", "staging", "prod"])
     
     name = "${var.project_name}-kv-${each.key}-${random_string.resource_suffix.result}"
     # ... configuration ...
   }
   ```

## 📞 Support

### Documentation Resources
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- [GitHub Actions Azure Login](https://github.com/Azure/login)

### Internal Resources
- Architecture Overview: `docs/architecture.md`
- Troubleshooting Guide: `docs/troubleshooting.md`
- Setup Instructions: `docs/setup.md`

### Emergency Contacts
- **DevOps Team**: For pipeline and access issues
- **Security Team**: For access policy and compliance questions
- **Azure Support**: For Azure Key Vault service issues

---

*This Key Vault integration provides enterprise-grade secret management for the LiveEventOps platform while maintaining security best practices and operational efficiency.*
