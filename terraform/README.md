# LiveEventOps Terraform Infrastructure

This directory contains Terraform configurations for provisioning Azure infrastructure for the LiveEventOps project.

## Overview

The Terraform configuration provisions a complete live event IT infrastructure simulation with:

- **Azure Resource Group**: Container for all resources
- **Virtual Network**: Hub-spoke network topology with multiple subnets
- **Subnets**: Management, Camera, Wireless, and DMZ subnets with network security groups
- **Virtual Machines**: 
  - 1x Management VM (Ubuntu, public IP)
  - 2x Camera simulation VMs (configurable count)
  - 3x Wireless AP simulation VMs (configurable count)  
  - 2x Printer simulation VMs (configurable count)
- **Static IP Assignments**: Each device VM has a predictable static IP
- **Azure Monitor Integration**: All VMs equipped with monitoring agents
- **Storage Account**: Blob storage for video content and configurations
- **Log Analytics Workspace**: Centralized logging and monitoring
- **Network Security Groups**: Protocol-specific security rules per device type

## Prerequisites

1. **Azure CLI**: Install and configure Azure CLI
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   az login
   ```

2. **Terraform**: Install Terraform (>= 1.0)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

3. **SSH Key Pair**: Generate SSH keys for VM access
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
   ```

## Quick Start

### 1. Set Up Remote State Backend

Run the backend setup script to create Azure Blob Storage for Terraform state:

```bash
chmod +x setup-backend.sh
./setup-backend.sh
```

This script will:
- Create a resource group for Terraform state
- Create a storage account with a unique name
- Create a blob container for state files
- Generate a `backend-config.tfvars` file

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Basic Configuration
resource_group_name = "liveeventops-rg"
location           = "East US"
environment        = "dev"
project_name       = "liveeventops"

# VM Configuration
vm_size        = "Standard_B2s"
admin_username = "azureuser"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-actual-public-key"

# Security Configuration
allowed_ip_ranges = ["YOUR_IP_ADDRESS/32"]
```

### 3. Initialize and Deploy

Initialize Terraform with the remote backend:

```bash
terraform init -backend-config=backend-config.tfvars
```

Plan the deployment:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

## File Structure

```
terraform/
├── main.tf                    # Main infrastructure configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables file
├── setup-backend.sh           # Backend setup script
├── backend-config.tfvars      # Backend configuration (generated)
└── README.md                  # This file
```

## Architecture

### Network Design

```
liveeventops-vnet (10.0.0.0/16)
├── management-subnet (10.0.1.0/24)   # Management VM with public access
├── camera-subnet (10.0.2.0/24)       # Camera VMs (10.0.2.10+)
├── wireless-subnet (10.0.3.0/24)     # Wireless AP VMs (10.0.3.10+)
└── dmz-subnet (10.0.4.0/24)          # Printer VMs (10.0.4.10+)
```

### Device VM Configuration

| Device Type | Default Count | VM Size | Static IP Range |
|-------------|---------------|---------|-----------------|
| Management | 1 | Standard_B2s | Dynamic + Public |
| Cameras | 2 | Standard_B1s | 10.0.2.10+ |
| Wireless APs | 3 | Standard_B1s | 10.0.3.10+ |
| Printers | 2 | Standard_B1s | 10.0.4.10+ |

### Security

- Network Security Groups (NSGs) with device-specific protocol rules
- SSH key authentication for all VMs (no password login)
- Jump box access pattern (device VMs accessible only via management VM)
- Network isolation between different device types
- Azure Monitor agents on all VMs for security monitoring

## Resource Naming Convention

Resources are named using the pattern:
```
{project-name}-{resource-type}-{random-suffix}
```

Examples:
- `liveeventops-vnet-a1b2c3d4`
- `management-vm-a1b2c3d4`
- `liveeventopsa1b2c3d4` (storage account, no hyphens)

## Outputs

After successful deployment, Terraform provides useful outputs:

```bash
# Get management VM public IP
terraform output management_vm_public_ip

# Get SSH connection command
terraform output ssh_connection_command

# Get all outputs in JSON format
terraform output -json
```

## Common Operations

### Connect to Management VM

```bash
# Using Terraform output
$(terraform output ssh_connection_command)

# Or manually (replace with actual IP)
ssh azureuser@<public-ip>
```

### Scale Resources

Modify variables in `terraform.tfvars` and apply:

```bash
# Change VM size
vm_size = "Standard_B4ms"

terraform plan
terraform apply
```

### Add Additional VMs

Extend `main.tf` with additional VM resources following the existing pattern.

### Update Network Security Rules

Modify the NSG rules in `main.tf` and apply changes:

```bash
terraform plan
terraform apply
```

## Cost Optimization

- Use appropriate VM sizes for your workload
- Enable auto-shutdown for development environments
- Monitor storage usage and implement lifecycle policies
- Use Azure Cost Management to track spending

## Security Best Practices

1. **Restrict SSH Access**: Update `allowed_ip_ranges` to specific IP addresses
2. **Use Strong SSH Keys**: Generate 4096-bit RSA keys or Ed25519 keys
3. **Regular Updates**: Keep VM operating systems updated
4. **Monitor Access**: Use Azure Monitor to track access patterns
5. **Network Segmentation**: Leverage NSGs to control inter-subnet communication

## Troubleshooting

### Backend Initialization Issues

```bash
# Force reconfigure backend
terraform init -reconfigure -backend-config=backend-config.tfvars

# Migrate from local to remote state
terraform init -migrate-state -backend-config=backend-config.tfvars
```

### VM Access Issues

```bash
# Check NSG rules
az network nsg show --resource-group liveeventops-rg --name management-nsg-*

# Verify SSH key format
ssh-keygen -l -f ~/.ssh/id_rsa.pub

# Test SSH connectivity
ssh -v azureuser@<public-ip>
```

### Storage Access Issues

```bash
# List storage containers
az storage container list --account-name <storage-account-name>

# Check storage account permissions
az storage account show --name <storage-account-name> --resource-group liveeventops-rg
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

To also clean up the backend resources:

```bash
# After terraform destroy
az group delete --name tfstate-rg --yes --no-wait
```

## Next Steps

1. **Add monitoring**: Implement Azure Monitor dashboards
2. **Automate deployments**: Set up GitHub Actions workflows
3. **Add more VMs**: Extend configuration for camera and wireless controller VMs
4. **Implement backup**: Configure automated backup policies
5. **Add security**: Implement Azure Key Vault integration

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Terraform and Azure documentation
3. Create an issue in the project repository
