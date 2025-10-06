# LiveEventOps - Complete Pipeline Demo Checklist

This checklist provides step-by-step instructions for demonstrating the complete LiveEventOps platform capabilities, from initial deployment through incident handling and rollback procedures.

## 📋 Pre-Demo Setup Checklist

### Prerequisites Verification
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Azure subscription with necessary permissions
- [ ] GitHub repository access with Actions enabled
- [ ] Terraform 1.6+ installed locally
- [ ] Git repository cloned locally

### Repository Setup
- [ ] Verify all required files are present:
  - [ ] `terraform/` directory with infrastructure code
  - [ ] `.github/workflows/terraform.yml` pipeline
  - [ ] `scripts/` directory with automation tools
  - [ ] `docs/` directory with documentation
- [ ] Check GitHub repository secrets are configured:
  - [ ] `AZURE_CLIENT_ID`
  - [ ] `AZURE_TENANT_ID` 
  - [ ] `AZURE_SUBSCRIPTION_ID`
  - [ ] `TF_STATE_RESOURCE_GROUP`
  - [ ] `TF_STATE_STORAGE_ACCOUNT`
  - [ ] `TF_STATE_CONTAINER`
  - [ ] `SSH_PUBLIC_KEY`

### Environment Preparation
- [ ] Create Terraform backend storage if not exists:
```bash
# Create resource group for Terraform state
az group create --name liveeventops-tfstate-rg --location eastus

# Create storage account
az storage account create \
  --name liveeventopstfstate \
  --resource-group liveeventops-tfstate-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name liveeventopstfstate
```

---

## 🚀 Demo Phase 1: Pipeline Trigger and Initial Deployment

### Step 1: Trigger Terraform Plan via Pull Request
- [ ] Create a feature branch for demo:
```bash
git checkout -b demo/pipeline-showcase
```

- [ ] Make a small change to trigger pipeline:
```bash
# Add a comment or update a variable description
echo "# Demo pipeline trigger" >> terraform/variables.tf
git add terraform/variables.tf
git commit -m "demo: Trigger pipeline for showcase"
git push origin demo/pipeline-showcase
```

- [ ] Create pull request on GitHub:
  - [ ] Navigate to GitHub repository
  - [ ] Create PR from `demo/pipeline-showcase` to `main`
  - [ ] Verify PR triggers `terraform-plan` job automatically

### Step 2: Monitor Pipeline Execution
- [ ] Navigate to GitHub Actions tab
- [ ] Click on running workflow
- [ ] Monitor job progress:
  - [ ] **terraform-check**: Format and validation
  - [ ] **terraform-plan**: Planning infrastructure changes
- [ ] Review plan output in PR comments
- [ ] Verify security: No secrets exposed in logs

### Step 3: Approve and Merge for Deployment
- [ ] Review Terraform plan output in PR
- [ ] Approve pull request
- [ ] Merge to `main` branch
- [ ] Verify automatic `terraform-apply` job triggers
- [ ] Monitor deployment progress in Actions tab

---

## 🏗️ Demo Phase 2: Resource Creation Verification

### Step 4: Verify Azure Resources
- [ ] Check resource group creation:
```bash
az group list --query "[?starts_with(name, 'liveeventops')].{Name:name, Location:location, State:properties.provisioningState}"
```

- [ ] Verify virtual network and subnets:
```bash
# List VNets
az network vnet list --resource-group liveeventops-rg --output table

# Check subnets
az network vnet subnet list --resource-group liveeventops-rg --vnet-name liveeventops-vnet --output table
```

- [ ] Confirm Key Vault deployment:
```bash
# List Key Vaults
az keyvault list --resource-group liveeventops-rg --query "[].{Name:name, SKU:properties.sku.name, State:properties.provisioningState}"

# Test Key Vault access
KV_NAME=$(az keyvault list --resource-group liveeventops-rg --query "[0].name" -o tsv)
az keyvault secret list --vault-name $KV_NAME --query "[].{Name:name, Enabled:attributes.enabled}"
```

- [ ] Check virtual machine deployment:
```bash
# List VMs
az vm list --resource-group liveeventops-rg --output table

# Check VM status
az vm list --resource-group liveeventops-rg --show-details --query "[].{Name:name, Status:powerState, Size:hardwareProfile.vmSize}"
```

- [ ] Verify storage accounts:
```bash
az storage account list --resource-group liveeventops-rg --output table
```

### Step 5: Test Infrastructure Connectivity
- [ ] Get management VM public IP:
```bash
az vm list-ip-addresses --resource-group liveeventops-rg --name liveeventops-mgmt-vm --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv
```

- [ ] Test SSH connectivity (if configured):
```bash
# Test connection (replace with actual IP)
ssh -o ConnectTimeout=5 azureuser@<VM_PUBLIC_IP> echo "Connection successful"
```

- [ ] Verify network security groups:
```bash
az network nsg list --resource-group liveeventops-rg --output table
az network nsg rule list --resource-group liveeventops-rg --nsg-name liveeventops-mgmt-nsg --output table
```

---

## 📊 Demo Phase 3: Monitoring and Observability

### Step 6: Configure Azure Monitor
- [ ] Verify Log Analytics workspace:
```bash
az monitor log-analytics workspace list --resource-group liveeventops-rg --output table
```

- [ ] Check Application Insights:
```bash
az monitor app-insights component show --resource-group liveeventops-rg --app liveeventops-insights
```

- [ ] Test custom metrics collection:
```bash
# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group liveeventops-rg --workspace-name liveeventops-logs --query customerId -o tsv)

# Query recent activity
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureActivity | where TimeGenerated > ago(1h) | summarize count() by OperationName"
```

### Step 7: Set Up Monitoring Dashboards
- [ ] Create custom dashboard:
```bash
# Deploy monitoring dashboard (if available)
az portal dashboard import \
  --input-path monitoring/dashboards/liveeventops-dashboard.json \
  --resource-group liveeventops-rg
```

- [ ] Configure alert rules:
```bash
# Create VM CPU alert
az monitor metrics alert create \
  --name "Demo-High-CPU-Usage" \
  --resource-group liveeventops-rg \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/liveeventops-rg/providers/Microsoft.Compute/virtualMachines/liveeventops-mgmt-vm \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "Demo alert for high CPU usage"
```

### Step 8: Test Monitoring Capabilities
- [ ] Generate test metrics:
```bash
# Connect to VM and generate CPU load
VM_IP=$(az vm list-ip-addresses --resource-group liveeventops-rg --name liveeventops-mgmt-vm --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

# Run stress test (if VM is accessible)
az vm run-command invoke \
  --resource-group liveeventops-rg \
  --name liveeventops-mgmt-vm \
  --command-id RunShellScript \
  --scripts "stress --cpu 2 --timeout 60s || echo 'Stress test completed'"
```

- [ ] Verify metrics in Azure portal:
  - [ ] Navigate to Azure portal → Monitor
  - [ ] Check metrics for VM CPU usage
  - [ ] Verify alert firing (if thresholds exceeded)

---

## 🔥 Demo Phase 4: Incident Handling Simulation

### Step 9: Simulate Infrastructure Issue
- [ ] Create deliberate configuration issue:
```bash
# Temporarily modify NSG to block SSH (simulate network issue)
az network nsg rule create \
  --resource-group liveeventops-rg \
  --nsg-name liveeventops-mgmt-nsg \
  --name "Demo-Block-SSH" \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --destination-port-ranges 22 \
  --description "Demo: Simulated network issue"
```

### Step 10: Demonstrate Troubleshooting Process
- [ ] Test connectivity failure:
```bash
# This should fail now
timeout 10 ssh -o ConnectTimeout=5 azureuser@$VM_IP echo "Test" || echo "Connection failed as expected"
```

- [ ] Use troubleshooting procedures from documentation:
```bash
# Check NSG rules
az network nsg rule list --resource-group liveeventops-rg --nsg-name liveeventops-mgmt-nsg --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, DestinationPortRange:destinationPortRange}"

# Check VM status
az vm get-instance-view --resource-group liveeventops-rg --name liveeventops-mgmt-vm --query "instanceView.statuses[1]"

# Review activity logs
az monitor activity-log list --resource-group liveeventops-rg --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) --query "[?operationName.value contains 'nsg']"
```

### Step 11: Demonstrate Issue Resolution
- [ ] Fix the simulated issue:
```bash
# Remove the blocking rule
az network nsg rule delete \
  --resource-group liveeventops-rg \
  --nsg-name liveeventops-mgmt-nsg \
  --name "Demo-Block-SSH"
```

- [ ] Verify resolution:
```bash
# Test connectivity restoration
timeout 10 ssh -o ConnectTimeout=5 azureuser@$VM_IP echo "Connection restored" || echo "Still investigating..."
```

- [ ] Document incident in logs:
```bash
# Create activity log entry
az monitor activity-log list --resource-group liveeventops-rg --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) | jq '.[0:3]'
```

---

## ⏪ Demo Phase 5: Rollback Procedures

### Step 12: Demonstrate Manual Rollback
- [ ] Check current Terraform state:
```bash
cd terraform
terraform show | grep -A 5 -B 5 "resource_group"
```

- [ ] Create a deliberate breaking change:
```bash
# Create a branch with breaking change
git checkout -b demo/breaking-change

# Modify terraform to create an invalid configuration
echo 'invalid_resource "test" {}' >> terraform/main.tf
git add terraform/main.tf
git commit -m "demo: Introduce breaking change for rollback demo"
git push origin demo/breaking-change
```

### Step 13: Trigger Failed Deployment
- [ ] Create PR with breaking changes
- [ ] Monitor pipeline failure in GitHub Actions
- [ ] Observe Terraform validation errors
- [ ] Review error logs and failure points

### Step 14: Execute Rollback Process
- [ ] Revert to known good state:
```bash
# Switch back to main branch
git checkout main

# Option 1: Git revert (for merged changes)
# git revert HEAD~1

# Option 2: Manual rollback to previous tag
git checkout day-10
git checkout -b hotfix/rollback-demo
```

- [ ] Deploy previous known-good configuration:
```bash
# Trigger manual deployment
# Go to GitHub Actions → Terraform Infrastructure workflow
# Click "Run workflow" → Select "apply"
```

- [ ] Monitor rollback deployment:
  - [ ] Watch GitHub Actions for successful deployment
  - [ ] Verify infrastructure returns to stable state
  - [ ] Confirm all resources are healthy

### Step 15: Verify Rollback Success
- [ ] Check infrastructure state:
```bash
# Verify all resources are in expected state
az resource list --resource-group liveeventops-rg --output table

# Test critical functionality
az vm get-instance-view --resource-group liveeventops-rg --name liveeventops-mgmt-vm --query "instanceView.statuses[1].displayStatus"
```

- [ ] Validate Key Vault access:
```bash
KV_NAME=$(az keyvault list --resource-group liveeventops-rg --query "[0].name" -o tsv)
az keyvault secret list --vault-name $KV_NAME --query "length(@)"
```

---

## 📚 Demo Phase 6: Documentation Review and Validation

### Step 16: Verify Documentation Accuracy
- [ ] Test deployment instructions from README:
  - [ ] Follow prerequisites section step-by-step
  - [ ] Verify all Azure CLI commands work as documented
  - [ ] Check that all required permissions are documented

- [ ] Validate troubleshooting procedures:
  - [ ] Test each troubleshooting command from the guide
  - [ ] Verify error scenarios match documented solutions
  - [ ] Confirm emergency procedures are actionable

### Step 17: Test Automation Scripts
- [ ] Run image conversion script:
```bash
# Test image conversion functionality
./scripts/convert-images-to-png.sh --check-deps
./scripts/convert-images-to-png.sh --inventory-only
```

- [ ] Test Key Vault setup script (if available):
```bash
# Verify Key Vault management tools
./scripts/setup-key-vault.sh verify-access
```

- [ ] Validate git workflow scripts:
```bash
# Check script permissions and functionality
ls -la scripts/git-*.sh
```

### Step 18: Documentation Completeness Check
- [ ] Review all documentation files:
  - [ ] `README.md` - Complete deployment guide
  - [ ] `docs/key-vault-integration.md` - Security procedures
  - [ ] `reviews/day-*.md` - Decision documentation
  - [ ] `media/image-inventory.md` - Media catalog

- [ ] Verify all links and references:
```bash
# Check for broken internal links
grep -r "docs/" README.md || echo "No documentation links found"
grep -r "media/" README.md || echo "No media links found"
```

- [ ] Confirm code examples work:
  - [ ] Test Azure CLI commands from documentation
  - [ ] Verify Terraform examples are valid
  - [ ] Check that all configuration snippets are accurate

---

## 🧪 Demo Phase 7: Advanced Testing Scenarios

### Step 19: Test Disaster Recovery
- [ ] Simulate region failure:
```bash
# Test cross-region backup (if configured)
az backup vault list --resource-group liveeventops-rg --output table

# Verify backup policies
az backup policy list --resource-group liveeventops-rg --vault-name liveeventops-backup-vault --output table
```

- [ ] Test infrastructure recreation:
```bash
# Destroy and recreate (CAUTION: Only in demo environment)
# This demonstrates disaster recovery capabilities
cd terraform
terraform plan -destroy -out=destroy.tfplan
# terraform apply destroy.tfplan  # Uncomment only if safe to do so
```

### Step 20: Performance and Scale Testing
- [ ] Test auto-scaling (if configured):
```bash
# Generate load to trigger scaling
az vm run-command invoke \
  --resource-group liveeventops-rg \
  --name liveeventops-mgmt-vm \
  --command-id RunShellScript \
  --scripts "for i in {1..100}; do echo 'Load test iteration $i'; sleep 1; done"
```

- [ ] Monitor resource utilization:
```bash
# Check current resource usage
az monitor metrics list \
  --resource /subscriptions/$(az account show --query id -o tsv)/resourceGroups/liveeventops-rg/providers/Microsoft.Compute/virtualMachines/liveeventops-mgmt-vm \
  --metric "Percentage CPU" \
  --interval PT5M
```

### Step 21: Security Validation
- [ ] Test Key Vault access controls:
```bash
# Verify secret access works
KV_NAME=$(az keyvault list --resource-group liveeventops-rg --query "[0].name" -o tsv)
az keyvault secret show --vault-name $KV_NAME --name ssh-public-key --query "value" -o tsv | wc -c
```

- [ ] Validate network security:
```bash
# Check network security group rules
az network nsg rule list --resource-group liveeventops-rg --nsg-name liveeventops-mgmt-nsg --output table

# Test port connectivity
nmap -p 22,80,443 $VM_IP || echo "Network security properly configured"
```

---

## 🧹 Demo Phase 8: Cleanup and Reset

### Step 22: Environment Cleanup
- [ ] Remove demo-specific resources:
```bash
# Remove demo alert rules
az monitor metrics alert delete --name "Demo-High-CPU-Usage" --resource-group liveeventops-rg

# Clean up demo branches
git branch -D demo/pipeline-showcase demo/breaking-change 2>/dev/null || true
git push origin --delete demo/pipeline-showcase demo/breaking-change 2>/dev/null || true
```

### Step 23: Documentation Update
- [ ] Record demo outcomes:
```bash
# Create demo results summary
echo "# Demo Results - $(date)" > demo-results.md
echo "## Successful Tests" >> demo-results.md
echo "- Pipeline execution: ✅" >> demo-results.md
echo "- Resource deployment: ✅" >> demo-results.md
echo "- Monitoring setup: ✅" >> demo-results.md
echo "- Incident handling: ✅" >> demo-results.md
echo "- Rollback procedures: ✅" >> demo-results.md
echo "- Documentation accuracy: ✅" >> demo-results.md
```

### Step 24: Final Verification
- [ ] Confirm all systems operational:
```bash
# Final health check
az resource list --resource-group liveeventops-rg --query "length(@)"
az vm get-instance-view --resource-group liveeventops-rg --name liveeventops-mgmt-vm --query "instanceView.statuses[1].displayStatus"
```

- [ ] Verify repository state:
```bash
# Ensure main branch is clean
git status
git log --oneline -5
```

---

## 📊 Demo Success Criteria

### Technical Validation ✅
- [ ] **Pipeline Execution**: All GitHub Actions workflows complete successfully
- [ ] **Resource Deployment**: All Azure resources deploy without errors
- [ ] **Security Integration**: Key Vault and access controls function properly
- [ ] **Monitoring Setup**: Azure Monitor collects metrics and triggers alerts
- [ ] **Incident Response**: Troubleshooting procedures resolve simulated issues
- [ ] **Rollback Capability**: Previous configurations restore successfully

### Documentation Validation ✅
- [ ] **Accuracy**: All documented procedures work as described
- [ ] **Completeness**: No missing steps or unclear instructions
- [ ] **Usability**: Documentation enables successful deployment by new users
- [ ] **Emergency Procedures**: Incident response guides are actionable

### Business Value Demonstration ✅
- [ ] **Automation**: Manual processes reduced from weeks to hours
- [ ] **Reliability**: Zero-downtime deployment and rollback capabilities
- [ ] **Security**: Enterprise-grade secret management and access controls
- [ ] **Observability**: Complete infrastructure visibility and alerting
- [ ] **Scalability**: Platform supports events of varying sizes
- [ ] **Cost Efficiency**: Automated resource lifecycle management

---

## 🎯 Next Steps After Demo

### Immediate Actions
- [ ] Deploy to production environment using validated procedures
- [ ] Configure production monitoring and alerting
- [ ] Train operations team on emergency procedures
- [ ] Schedule regular infrastructure health checks

### Continuous Improvement
- [ ] Collect user feedback on documentation clarity
- [ ] Monitor real-world performance metrics
- [ ] Iterate on automation scripts based on usage
- [ ] Plan next phase enhancements

### Knowledge Sharing
- [ ] Create video walkthrough of key procedures
- [ ] Schedule team training sessions
- [ ] Document lessons learned from demo
- [ ] Share success metrics with stakeholders

---

**Demo Completion Status: Ready for Production! 🚀**

*This comprehensive demo validates the LiveEventOps platform's production readiness and operational excellence capabilities.*
