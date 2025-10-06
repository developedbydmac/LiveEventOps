# GitHub Actions Setup for Terraform

This document explains how to set up GitHub Actions secrets and service principals for automated Terraform deployments.

## Required Secrets

The following secrets need to be configured in your GitHub repository:

### 1. Azure Service Principal (`AZURE_CREDENTIALS`)

Create a service principal for GitHub Actions to authenticate with Azure:

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "liveeventops-github-actions" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

This will output JSON that should be stored in the `AZURE_CREDENTIALS` secret:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### 2. SSH Public Key (`SSH_PUBLIC_KEY`)

Your SSH public key for VM access:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key content
cat ~/.ssh/id_rsa.pub
```

### 3. Terraform Backend Configuration

After running the `setup-backend.sh` script, you'll need these secrets:

- `TF_STATE_RESOURCE_GROUP`: Resource group name for Terraform state (e.g., `tfstate-rg`)
- `TF_STATE_STORAGE_ACCOUNT`: Storage account name for Terraform state (e.g., `tfstateabcd1234`)
- `TF_STATE_CONTAINER`: Container name for Terraform state (e.g., `tfstate`)

## Setting Up Secrets in GitHub

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the corresponding name and value

### Required Secrets Summary

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CREDENTIALS` | Azure service principal JSON | `{"clientId": "...", ...}` |
| `SSH_PUBLIC_KEY` | SSH public key for VM access | `ssh-rsa AAAAB3NzaC1yc2E...` |
| `TF_STATE_RESOURCE_GROUP` | Terraform state resource group | `tfstate-rg` |
| `TF_STATE_STORAGE_ACCOUNT` | Terraform state storage account | `tfstateabcd1234` |
| `TF_STATE_CONTAINER` | Terraform state container | `tfstate` |

## GitHub Environments

The workflow uses a `production` environment for apply and destroy operations. Set this up:

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name it `production`
4. Configure protection rules (optional but recommended):
   - Required reviewers
   - Wait timer
   - Deployment branches (restrict to `main`)

## Workflow Triggers

The Terraform workflow is triggered by:

1. **Push to main/develop**: Runs format check, validate, and apply (main only)
2. **Pull requests to main**: Runs format check, validate, and plan
3. **Manual workflow dispatch**: Allows choosing plan, apply, or destroy

## Workflow Jobs

### terraform-check
- Runs on all triggers
- Checks Terraform formatting
- Validates Terraform configuration
- Comments on PRs if formatting issues are found

### terraform-plan
- Runs on pull requests and manual plan
- Shows what changes will be made
- Comments plan results on PRs

### terraform-apply
- Runs on main branch pushes and manual apply
- Requires `production` environment approval
- Applies infrastructure changes
- Saves outputs as artifacts

### terraform-destroy
- Runs only on manual destroy
- Requires `production` environment approval
- Destroys all infrastructure

## Security Best Practices

1. **Least Privilege**: The service principal only has Contributor access to the specific subscription
2. **Environment Protection**: Production environment requires approval
3. **Secret Rotation**: Regularly rotate service principal credentials
4. **Branch Protection**: Configure branch protection rules for the main branch

## Troubleshooting

### Authentication Issues

```bash
# Test service principal authentication
az login --service-principal \
  --username $CLIENT_ID \
  --password $CLIENT_SECRET \
  --tenant $TENANT_ID

# Verify permissions
az role assignment list --assignee $CLIENT_ID
```

### Backend Issues

```bash
# Verify backend resources exist
az group show --name tfstate-rg
az storage account show --name $STORAGE_ACCOUNT --resource-group tfstate-rg
az storage container show --name tfstate --account-name $STORAGE_ACCOUNT
```

### Workflow Failures

1. Check the Actions tab for detailed logs
2. Verify all secrets are set correctly
3. Ensure the service principal has proper permissions
4. Check that the backend resources exist

## Local Development

For local development, you can still use the same backend:

```bash
# Initialize with backend configuration
terraform init -backend-config=backend-config.tfvars

# Plan with your SSH key
terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# Apply (be careful in production!)
terraform apply
```

## Next Steps

1. Test the workflow with a pull request
2. Monitor the Actions tab for execution
3. Verify infrastructure is created correctly
4. Set up monitoring and alerting for the deployed resources
