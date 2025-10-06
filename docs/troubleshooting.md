# Automated Troubleshooting & Incident Response

This document describes the automated troubleshooting and incident response system for the LiveEventOps platform. The system provides comprehensive VM diagnostics, automated remediation, and incident tracking through Azure Monitor integration with GitHub Actions.

## 🎯 Overview

The automated troubleshooting system consists of three main components:

1. **VM Diagnostics Script** (`scripts/vm-diagnostics.sh`) - Comprehensive Azure CLI-based diagnostics and remediation
2. **GitHub Actions Workflow** (`.github/workflows/incident-response.yml`) - Automated incident response triggered by Azure Monitor alerts
3. **Webhook Integration** (`scripts/setup-webhook.sh`) - Connects Azure Monitor alerts to GitHub Actions

## 🔧 VM Diagnostics Script

### Features
- **Multi-action Support**: Diagnose, restart, logs-only, and health-check modes
- **Comprehensive Metrics**: CPU, memory, network, and heartbeat analysis
- **Log Analytics Integration**: Retrieves system logs, performance counters, and heartbeat data
- **Health Scoring**: Algorithmic health assessment with actionable recommendations
- **Automated Remediation**: Intelligent VM restart based on health analysis
- **Notification Support**: Webhook notifications for critical events

### Usage Examples

```bash
# Full diagnostics for a specific VM
./scripts/vm-diagnostics.sh -g liveeventops-rg -v management-vm-abc123 -a diagnose

# Health check for all VMs in resource group
./scripts/vm-diagnostics.sh -g liveeventops-rg -a health-check

# Restart unhealthy VM automatically
./scripts/vm-diagnostics.sh -g liveeventops-rg -v camera-1-abc123 -a restart

# Gather logs only
./scripts/vm-diagnostics.sh -g liveeventops-rg -v printer-vm-abc123 -a logs
```

### Health Scoring Algorithm

The script uses a 100-point health scoring system:

| Issue | Score Impact | Threshold |
|-------|-------------|-----------|
| VM Not Running | -50 points | Power state check |
| High CPU Usage | -20 points | >80% average |
| Low Memory | -25 points | <100MB available |
| Missing Heartbeat | -30 points | <5 records in last hour |

**Health Categories:**
- **Healthy**: 71-100 points (🟢)
- **Degraded**: 41-70 points (🟡)
- **Unhealthy**: 0-40 points (🔴)

### Environment Variables

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export LOG_ANALYTICS_WORKSPACE_NAME="liveeventops-workspace"
export WEBHOOK_URL="https://your-notification-webhook.com"
```

## 🤖 GitHub Actions Incident Response

### Trigger Types

1. **Azure Monitor Alerts** - Automatic response via webhook
2. **Manual Dispatch** - Manual testing and troubleshooting
3. **Repository Dispatch** - External system integration

### Workflow Features

- **Alert Parsing**: Extracts VM name, severity, and alert type from Azure Monitor payloads
- **Severity-based Actions**: Critical alerts trigger automatic restart, warnings trigger diagnostics
- **Artifact Collection**: Saves all diagnostic files for analysis
- **Issue Creation**: Creates GitHub issues for critical incidents
- **Notification System**: Sends status updates via webhook
- **Comprehensive Reporting**: Generates detailed incident reports

### Manual Workflow Execution

```bash
# Health check all VMs
gh workflow run incident-response.yml -f action=health-check

# Diagnose specific VM
gh workflow run incident-response.yml -f action=diagnose -f vm_name=camera-1-abc123

# Force restart VM
gh workflow run incident-response.yml -f action=restart -f vm_name=management-vm-abc123
```

### Required GitHub Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `AZURE_CLIENT_ID` | Service principal client ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdef01-2345-6789-abcd-ef0123456789` |
| `WEBHOOK_URL` | Optional notification webhook | `https://your-webhook.example.com/endpoint` |

## 🔗 Webhook Integration

### Setup Process

1. **Configure Azure Monitor Action Group**
   ```bash
   ./scripts/setup-webhook.sh -o your-github-org -r liveeventops -t ghp_your_token
   ```

2. **Test Webhook Connection**
   ```bash
   # Manual test using generated payload
   curl -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     -H "Content-Type: application/json" \
     -d @webhook-test-payload.json \
     "https://api.github.com/repos/owner/repo/dispatches"
   ```

3. **Verify GitHub Actions Trigger**
   - Check Actions tab in GitHub repository
   - Look for "Incident Response Automation" workflow runs
   - Review workflow logs for execution details

### Alert Flow Diagram

```
Azure Monitor Alert
        ↓
Action Group Webhook
        ↓
GitHub Repository Dispatch
        ↓
Incident Response Workflow
        ↓
VM Diagnostics Script
        ↓
Health Analysis & Remediation
        ↓
Incident Report & Artifacts
```

## 📊 Monitoring & Alerting Integration

### Azure Monitor Alert Rules

The system responds to these pre-configured alert types:

| Alert Type | Metric | Threshold | Action |
|------------|--------|-----------|--------|
| High CPU | Percentage CPU | >80% for 5 min | Diagnose |
| Low Memory | Available Memory | <100MB for 5 min | Diagnose |
| VM Heartbeat | Heartbeat | Missing for 10 min | Restart |
| Network Issues | Network In/Out | Anomaly detection | Diagnose |

### Severity Mapping

| Azure Severity | Description | Automated Action |
|----------------|-------------|------------------|
| 0 (Critical) | Service down | Immediate restart |
| 1 (Error) | Performance critical | Restart if unhealthy |
| 2 (Warning) | Performance degraded | Diagnose only |
| 3 (Informational) | Threshold breach | Log analysis |

## 📋 Incident Response Procedures

### Automatic Response Flow

1. **Alert Detection** - Azure Monitor detects threshold breach
2. **Webhook Trigger** - Action group sends webhook to GitHub
3. **Workflow Execution** - Incident response workflow starts
4. **Diagnostics** - VM health analysis and metric collection
5. **Remediation** - Automatic restart for critical issues
6. **Documentation** - Issue creation and artifact storage
7. **Notification** - Status updates via configured webhooks

### Manual Intervention Points

- **Before Restart**: Review health analysis output
- **During Execution**: Monitor workflow logs in real-time
- **After Completion**: Review generated incident reports
- **Escalation**: Create manual GitHub issues for complex problems

## 🗂️ File Structure

```
scripts/
├── vm-diagnostics.sh           # Main diagnostics script
├── setup-webhook.sh           # Webhook configuration script
└── git-workflow.sh            # Git automation (existing)

.github/workflows/
├── terraform.yml              # Infrastructure deployment
└── incident-response.yml      # Automated troubleshooting

docs/
├── troubleshooting.md         # This document
├── architecture.md           # System architecture
└── setup.md                  # Setup instructions
```

## 🔍 Diagnostic Output

### Generated Files

Each diagnostic run creates timestamped output directory containing:

- `{vm_name}_info.json` - VM configuration and status
- `{vm_name}_cpu_metrics.json` - CPU utilization data
- `{vm_name}_memory_metrics.json` - Memory usage data
- `{vm_name}_network_metrics.json` - Network traffic data
- `{vm_name}_syslog.json` - System logs from Log Analytics
- `{vm_name}_performance.json` - Performance counters
- `{vm_name}_heartbeat.json` - VM heartbeat data
- `{vm_name}_health_analysis.json` - Health scoring results
- `health_check_summary.json` - Multi-VM health summary
- `diagnostic_report.md` - Human-readable report

### Health Analysis Schema

```json
{
  "vm_name": "management-vm-abc123",
  "health_score": 85,
  "status": "healthy",
  "issues": [],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Health Check Summary Schema

```json
{
  "resource_group": "liveeventops-rg",
  "total_vms": 8,
  "healthy_vms": 6,
  "unhealthy_vms": 2,
  "unhealthy_vm_list": ["camera-2-abc123", "printer-1-abc123"],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## 🚨 Troubleshooting Common Issues

### Script Execution Problems

**Issue**: Permission denied
```bash
chmod +x scripts/*.sh
```

**Issue**: Azure CLI not authenticated
```bash
az login
az account set --subscription "your-subscription-id"
```

**Issue**: Missing dependencies
```bash
# Ubuntu/Debian
sudo apt-get install jq bc curl

# macOS
brew install jq
```

### GitHub Actions Issues

**Issue**: Workflow not triggering
- Verify webhook URL in Azure action group
- Check GitHub token permissions (needs `repo` scope)
- Ensure workflow file is in default branch

**Issue**: Azure authentication failure
- Verify service principal credentials in GitHub secrets
- Check Azure RBAC permissions for service principal
- Ensure subscription ID is correct

### Azure Monitor Integration

**Issue**: Webhook not receiving alerts
- Verify action group webhook configuration
- Check Azure Monitor alert rule conditions
- Test webhook manually using curl

**Issue**: Log Analytics queries failing
- Verify workspace name and permissions
- Check if Azure Monitor agent is installed on VMs
- Ensure data collection rules are configured

## 📈 Performance Considerations

### Script Optimization

- **Parallel Execution**: Use background processes for multiple VM analysis
- **Caching**: Cache Azure CLI authentication tokens
- **Rate Limiting**: Respect Azure API limits with backoff strategies
- **Output Filtering**: Use jq for efficient JSON processing

### Cost Optimization

- **Log Analytics**: Configure appropriate data retention policies
- **Alert Frequency**: Set reasonable evaluation frequencies
- **Webhook Efficiency**: Batch multiple alerts when possible
- **Storage**: Clean up old diagnostic artifacts regularly

## 🔒 Security Considerations

### Authentication & Authorization

- **Service Principal**: Use dedicated service principal with minimal required permissions
- **Token Security**: Store GitHub tokens securely in GitHub Secrets
- **Network Security**: Restrict webhook endpoints to Azure IP ranges if possible
- **Audit Trail**: Enable audit logging for all diagnostic actions

### Data Protection

- **Sensitive Data**: Avoid logging sensitive information in diagnostic outputs
- **Access Control**: Restrict GitHub repository access to authorized personnel
- **Encryption**: Ensure all data transmission uses HTTPS/TLS
- **Retention**: Implement appropriate data retention policies

## 📚 Related Documentation

- [Architecture Overview](architecture.md) - System design and components
- [Setup Guide](setup.md) - Initial system configuration
- [Terraform Infrastructure](../terraform/README.md) - Infrastructure as Code
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🆘 Support & Escalation

### Internal Escalation

1. **Level 1**: Automated diagnostics and restart attempts
2. **Level 2**: Manual intervention using diagnostic outputs
3. **Level 3**: Infrastructure team engagement for complex issues

### External Resources

- **Azure Support**: For Azure-specific service issues
- **GitHub Support**: For GitHub Actions or API problems
- **Vendor Support**: For device-specific problems (cameras, printers, etc.)

### Emergency Contacts

Configure emergency notification webhooks for critical incidents that require immediate human intervention.

---

*This troubleshooting system is designed to minimize manual intervention while providing comprehensive visibility into system health and performance. Regular testing and maintenance ensure reliable automated incident response.*
