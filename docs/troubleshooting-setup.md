# Quick Setup Guide - Automated Troubleshooting

This guide provides step-by-step instructions to set up the automated troubleshooting and incident response system for LiveEventOps.

## 📋 Prerequisites Checklist

- [ ] Azure CLI installed and configured
- [ ] GitHub repository with admin access
- [ ] Azure subscription with contributor permissions
- [ ] Terraform infrastructure deployed (main.tf applied)
- [ ] Log Analytics workspace created
- [ ] Azure Monitor action groups configured

## 🚀 Setup Steps

### 1. Configure GitHub Repository Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

```bash
# Azure Service Principal Credentials
AZURE_CLIENT_ID=12345678-1234-1234-1234-123456789012
AZURE_TENANT_ID=87654321-4321-4321-4321-210987654321
AZURE_SUBSCRIPTION_ID=abcdef01-2345-6789-abcd-ef0123456789

# Optional: Notification webhook URL (replace with your actual webhook)
WEBHOOK_URL=https://your-notification-webhook.example.com
```

### 2. Set Up Azure Monitor Webhook Integration

```bash
# Navigate to project directory
cd /path/to/LiveEventOps

# Make scripts executable
chmod +x scripts/*.sh

# Configure webhook (replace with your GitHub details)
./scripts/setup-webhook.sh \
  -o your-github-username \
  -r LiveEventOps \
  -t ghp_your_github_token_here
```

### 3. Test VM Diagnostics Script

```bash
# Test health check for all VMs
./scripts/vm-diagnostics.sh \
  -g liveeventops-rg \
  -a health-check

# Test diagnostics for specific VM
./scripts/vm-diagnostics.sh \
  -g liveeventops-rg \
  -v management-vm-abc123 \
  -a diagnose
```

### 4. Test GitHub Actions Workflow

```bash
# Install GitHub CLI if not already installed
# macOS: brew install gh
# Ubuntu: sudo apt install gh

# Authenticate with GitHub
gh auth login

# Test manual workflow trigger
gh workflow run incident-response.yml \
  -f action=health-check
```

### 5. Verify Azure Monitor Integration

```bash
# Check that action group webhook is configured
az monitor action-group show \
  --resource-group liveeventops-rg \
  --name liveeventops-incident-response \
  --query 'webhookReceivers[].name'

# Test webhook using generated test payload
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d @webhook-test-payload.json \
  "https://api.github.com/repos/YOUR_OWNER/YOUR_REPO/dispatches"
```

## 🧪 Testing Scenarios

### Scenario 1: Manual Health Check
```bash
# Trigger manual health check
gh workflow run incident-response.yml -f action=health-check

# Check workflow status
gh run list --workflow=incident-response.yml --limit=1
```

### Scenario 2: Simulate High CPU Alert
```bash
# SSH to a VM and create CPU load
ssh azureuser@your-vm-ip "stress --cpu 4 --timeout 300s"

# Monitor for Azure Monitor alert trigger
# Check GitHub Actions for automatic workflow execution
```

### Scenario 3: Test VM Restart Procedure
```bash
# Stop a VM to trigger heartbeat alert
az vm stop --resource-group liveeventops-rg --name camera-1-abc123

# Wait for alert and automatic remediation
# Verify VM is restarted automatically
```

## ⚠️ Troubleshooting Setup Issues

### GitHub Actions Not Triggering

**Problem**: Webhook not triggering GitHub Actions
**Solution**:
```bash
# Verify webhook configuration
az monitor action-group show \
  --resource-group liveeventops-rg \
  --name liveeventops-incident-response

# Check GitHub webhook deliveries
# GitHub Repository > Settings > Webhooks > Recent Deliveries
```

### Azure CLI Authentication Issues

**Problem**: Azure CLI commands failing
**Solution**:
```bash
# Re-authenticate with Azure
az login

# Set correct subscription
az account set --subscription "your-subscription-id"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

### VM Diagnostics Script Errors

**Problem**: Script cannot access Log Analytics
**Solution**:
```bash
# Verify Log Analytics workspace exists
az monitor log-analytics workspace show \
  --resource-group liveeventops-rg \
  --workspace-name liveeventops-workspace

# Check if Azure Monitor agent is installed on VMs
az vm extension list \
  --resource-group liveeventops-rg \
  --vm-name management-vm-abc123 \
  --query '[?name==`AzureMonitorLinuxAgent`]'
```

## 📊 Monitoring Setup Completion

### Verification Checklist

- [ ] GitHub repository secrets configured
- [ ] Webhook integration setup completed
- [ ] VM diagnostics script tested successfully
- [ ] GitHub Actions workflow manually triggered
- [ ] Azure Monitor alerts configured and tested
- [ ] Log Analytics workspace accessible
- [ ] Emergency notification webhook configured

### Health Check Commands

```bash
# Verify all components
./scripts/vm-diagnostics.sh -g liveeventops-rg -a health-check

# Check GitHub Actions workflow history
gh run list --workflow=incident-response.yml --limit=5

# Verify Azure Monitor alerts
az monitor alert list --resource-group liveeventops-rg --output table
```

## 🔄 Ongoing Maintenance

### Daily Operations
- Monitor GitHub Actions workflow execution logs
- Review diagnostic reports in repository artifacts
- Check Azure Monitor alert rule effectiveness

### Weekly Maintenance
- Test manual workflow triggers
- Review and clean up old diagnostic artifacts
- Verify webhook connectivity and authentication

### Monthly Review
- Analyze incident response metrics
- Update alert thresholds based on performance data
- Review and update documentation

## 📞 Support Contacts

For setup assistance or troubleshooting:

1. **Technical Issues**: Create GitHub issue with `setup` label
2. **Azure Integration**: Check Azure Monitor documentation
3. **GitHub Actions**: Review GitHub Actions documentation
4. **Emergency**: Use configured webhook notifications

## 📚 Next Steps

After completing setup:

1. Read [Troubleshooting Documentation](troubleshooting.md) for detailed system information
2. Review [Architecture Overview](architecture.md) for system design
3. Customize alert thresholds in Terraform configuration
4. Set up additional notification channels as needed
5. Train team on incident response procedures

---

**Setup Time Estimate**: 30-45 minutes
**Prerequisites Time**: 15-30 minutes (if Terraform already deployed)
**Testing Time**: 15-20 minutes

*This automated troubleshooting system will significantly reduce manual intervention for common VM issues while providing comprehensive visibility into system health.*
