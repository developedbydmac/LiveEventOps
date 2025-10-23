# LiveEventOps Bicep Infrastructure

This directory contains Azure Bicep templates for provisioning the LiveEventOps infrastructure.

## Overview

The Bicep templates provide an Azure-native Infrastructure as Code (IaC) solution that provisions:
- Virtual Network with 4 subnets (management, camera, wireless, DMZ)
- Management VM with Ubuntu 22.04 LTS
- Azure Key Vault for secrets management
- Storage Account with blob containers
- Log Analytics Workspace and Application Insights
- Network Security Groups and access controls
- User-assigned managed identity with RBAC

## Quick Start

### Prerequisites
- Azure CLI with Bicep extension
- Azure subscription with Contributor permissions
- SSH public key for VM access

### Deploy Infrastructure

1. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Create Resource Group**:
   ```bash
   az group create --name liveeventops-rg --location eastus
   ```

3. **Customize Parameters**:
   ```bash
   cp parameters.json parameters.local.json
   # Edit parameters.local.json with your SSH public key and preferences
   ```

4. **Deploy Template**:
   ```bash
   az deployment group create \
     --resource-group liveeventops-rg \
     --template-file main.bicep \
     --parameters @parameters.local.json
   ```

5. **Verify Deployment**:
   ```bash
   az deployment group show \
     --resource-group liveeventops-rg \
     --name main \
     --output table
   ```

## Architecture

### Network Design
- **Virtual Network**: 10.0.0.0/16 with 4 subnets
- **Management Subnet**: 10.0.1.0/24 (VM and administration)
- **Camera Subnet**: 10.0.2.0/24 (Camera device simulation)
- **Wireless Subnet**: 10.0.3.0/24 (AP and wireless management)
- **DMZ Subnet**: 10.0.4.0/24 (Public-facing services)

### Security Features
- User-assigned managed identity for secure access
- Key Vault with RBAC for secret management
- Network Security Groups with minimal required access
- Storage account with private blob access
- SSH key authentication (no password access)

### Monitoring and Observability
- Log Analytics Workspace for centralized logging
- Application Insights for application monitoring
- Resource tagging for cost management and organization

## Resource Naming

Resources follow the pattern: `{prefix}-{resource-type}-{unique-suffix}`

Examples:
- `liveeventops-vnet-abc123`
- `liveeventops-kv-abc123`
- `liveeventops-management-vm`

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `environment` | string | Environment name (dev/staging/prod) | `dev` |
| `location` | string | Azure region for deployment | Resource group location |
| `sshPublicKey` | securestring | SSH public key for VM access | Required |
| `webhookUrl` | securestring | Monitoring webhook URL | Empty |
| `alertEmail` | string | Email for monitoring alerts | `admin@liveeventops.com` |
| `prefix` | string | Resource naming prefix | `liveeventops` |

## Outputs

The template provides the following outputs:
- Resource group name
- Virtual network name
- Key Vault name
- Management VM details (name, IP, FQDN)
- Storage account name
- Monitoring resource names
- Managed identity details
- SSH connection command

## Post-Deployment

### Connect to Management VM
```bash
# Use the SSH command from template outputs
ssh azureuser@<public-ip>

# Or use FQDN
ssh azureuser@<vm-fqdn>
```

### Access Key Vault
```bash
# List secrets (requires appropriate RBAC permissions)
az keyvault secret list --vault-name <key-vault-name>

# Get secret value
az keyvault secret show --vault-name <key-vault-name> --name ssh-public-key
```

### Monitor Resources
```bash
# Check VM status
az vm show --resource-group liveeventops-rg --name liveeventops-management-vm --show-details

# View Log Analytics workspace
az monitor log-analytics workspace show --resource-group liveeventops-rg --workspace-name <workspace-name>
```

## Cost Optimization

- **VM Size**: Standard_B2s (burstable, cost-effective for development)
- **Storage**: Standard_LRS (locally redundant, lower cost)
- **Log Analytics**: Pay-per-GB pricing with 30-day retention
- **Key Vault**: Standard tier (sufficient for most use cases)

Estimated monthly cost for development environment: $50-100 USD

## Security Best Practices

1. **Access Control**: Use Azure RBAC for granular permissions
2. **Secret Management**: Store all sensitive data in Key Vault
3. **Network Security**: Implement NSG rules and private endpoints
4. **Monitoring**: Enable diagnostic settings for all resources
5. **Updates**: Keep VM OS and applications updated

## Troubleshooting

### Common Issues

**Deployment Failures**:
```bash
# Check deployment status
az deployment group show --resource-group liveeventops-rg --name main

# View deployment operations
az deployment operation group list --resource-group liveeventops-rg --name main
```

**VM Access Issues**:
```bash
# Check VM status
az vm get-instance-view --resource-group liveeventops-rg --name liveeventops-management-vm

# Reset SSH configuration
az vm user reset-ssh --resource-group liveeventops-rg --name liveeventops-management-vm
```

**Key Vault Access**:
```bash
# Check access policies
az keyvault show --name <key-vault-name> --query properties.accessPolicies

# Verify RBAC assignments
az role assignment list --scope <key-vault-resource-id>
```

## Cleanup

To remove all resources:
```bash
az group delete --name liveeventops-rg --yes --no-wait
```

## Integration with CI/CD

This template is designed to work with GitHub Actions. See the `.github/workflows/bicep.yml` for automated deployment.

Required secrets for GitHub Actions:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID` 
- `AZURE_SUBSCRIPTION_ID`
- `SSH_PUBLIC_KEY`

## Next Steps

1. **Deploy the infrastructure** using the template
2. **Configure monitoring** with custom dashboards
3. **Set up automated backups** for critical data
4. **Implement additional VMs** for device simulation
5. **Configure application deployment** pipelines

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Bicep documentation
3. Create an issue in the project repository
