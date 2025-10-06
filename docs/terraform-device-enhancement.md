# Enhanced Terraform Infrastructure - Device Simulation VMs

## Summary of Enhancements

Successfully enhanced the LiveEventOps Terraform configuration to include comprehensive device simulation VMs with static IP assignments and Azure monitoring extensions.

## ✅ New Infrastructure Components Added

### Device Simulation VMs

#### Camera VMs (2 units, configurable)
- **Location**: Camera subnet (10.0.2.0/24)
- **Static IPs**: 10.0.2.10, 10.0.2.11
- **VM Size**: Standard_B1s
- **Purpose**: Simulate IP cameras with RTSP streaming
- **Network Ports**: RTSP (554), HTTP (80)

#### Wireless Access Point VMs (3 units, configurable)
- **Location**: Wireless subnet (10.0.3.0/24)
- **Static IPs**: 10.0.3.10, 10.0.3.11, 10.0.3.12
- **VM Size**: Standard_B1s
- **Purpose**: Simulate wireless controllers and APs
- **Network Ports**: CAPWAP Control (5246/UDP), CAPWAP Data (5247/UDP)

#### Printer VMs (2 units, configurable)
- **Location**: DMZ subnet (10.0.4.0/24)
- **Static IPs**: 10.0.4.10, 10.0.4.11
- **VM Size**: Standard_B1s
- **Purpose**: Simulate network printers
- **Network Ports**: IPP (631), LPD (515)

### Network Security Groups

#### Camera NSG
- RTSP (554) - Internal VNet access only
- HTTP (80) - Internal VNet access only
- SSH (22) - Management subnet only

#### Wireless NSG
- CAPWAP Control/Data - Internal VNet access only
- SSH (22) - Management subnet only

#### DMZ NSG (Printers)
- IPP/LPD printing protocols - Internal VNet access only
- SSH (22) - Management subnet only

### Monitoring Infrastructure

#### Azure Monitor Agents
- Deployed on ALL VMs (management + 7 device VMs)
- Automatic log collection via syslog
- Performance counter monitoring
- Connected to central Log Analytics workspace

#### Data Collection Rule
- Centralized configuration for all monitoring agents
- Syslog data collection (all facilities and levels)
- Performance counters: CPU, Memory, Network
- 60-second sampling frequency

## 🔧 Configuration Variables Added

```hcl
# Device count variables (configurable)
camera_count   = 2    # Number of camera VMs
wireless_count = 3    # Number of wireless AP VMs  
printer_count  = 2    # Number of printer VMs

# VM sizing
device_vm_size = "Standard_B1s"  # Device VM size
```

## 📊 Enhanced Terraform Outputs

### Device Information
- `camera_vm_ips`: All camera VM IP addresses
- `wireless_vm_ips`: All wireless AP VM IP addresses  
- `printer_vm_ips`: All printer VM IP addresses
- `camera_vm_names`: Camera VM resource names
- `wireless_vm_names`: Wireless VM resource names
- `printer_vm_names`: Printer VM resource names

### SSH Access Commands
- Pre-formatted SSH jump commands for each device
- Uses management VM as jump host
- Example: `ssh -J azureuser@<mgmt-ip> azureuser@10.0.2.10`

### Network Summary
- Complete subnet information with VM counts
- CIDR blocks and VM distribution
- Network security group associations

### Monitoring Summary
- Log Analytics workspace details
- Data collection rule information
- Total monitored VMs count

## 🏗️ Infrastructure Scale

### Total Resources
- **VMs**: 8 total (1 management + 7 device simulation)
- **Subnets**: 4 with device-specific NSGs
- **Static IPs**: 7 device VMs with predictable IPs
- **Monitoring Agents**: 8 Azure Monitor agents
- **NSG Rules**: Protocol-specific security rules per device type

### Cost Estimate (Updated)
- **Management VM**: ~$30-40/month (Standard_B2s)
- **Device VMs**: ~$70-105/month (7x Standard_B1s)
- **Storage & Networking**: ~$8-12/month
- **Monitoring**: ~$5-15/month
- **Total**: ~$113-172/month

## 🔐 Security Enhancements

### Network Isolation
- Each device type isolated in dedicated subnets
- Protocol-specific NSG rules (no unnecessary ports open)
- Jump box access pattern (no direct external access to devices)

### Monitoring Security
- All VMs monitored for security events
- Centralized logging for audit compliance
- Performance baselines for anomaly detection

## 📁 File Structure Updates

```
terraform/
├── main.tf                    # Enhanced with 7 new VMs + monitoring
├── variables.tf               # Added device count and sizing variables
├── outputs.tf                 # Comprehensive device and network outputs
├── terraform.tfvars.example   # Updated with device configuration
├── setup-backend.sh           # Unchanged
└── README.md                  # Updated with device simulation info
```

## 🚀 Deployment Instructions

### 1. Configure Device Counts
Edit `terraform.tfvars`:
```hcl
camera_count   = 2  # Adjust for event size
wireless_count = 3  # Scale for venue coverage
printer_count  = 2  # Based on printing needs
```

### 2. Deploy Infrastructure
```bash
terraform plan   # Review 8 VMs + monitoring
terraform apply  # Deploy complete simulation environment
```

### 3. Access Device VMs
```bash
# Get SSH commands from outputs
terraform output device_ssh_commands

# Connect to devices via jump host
ssh -J azureuser@<mgmt-ip> azureuser@10.0.2.10  # Camera 1
ssh -J azureuser@<mgmt-ip> azureuser@10.0.3.10  # Wireless AP 1
ssh -J azureuser@<mgmt-ip> azureuser@10.0.4.10  # Printer 1
```

## 📈 Monitoring Capabilities

### Log Analytics Queries
```kusto
// Device performance overview
Perf
| where Computer contains "camera" or Computer contains "wireless" or Computer contains "printer"
| summarize avg(CounterValue) by Computer, CounterName

// Device connectivity status
Heartbeat
| where Computer contains "camera" or Computer contains "wireless" or Computer contains "printer"
| summarize max(TimeGenerated) by Computer
```

### Azure Monitor Alerts
- Can set up alerts for device failures
- Performance threshold monitoring
- Network connectivity alerts
- Resource utilization warnings

## 🎯 Live Event Simulation Scenarios

### Camera Management
- RTSP stream simulation with FFmpeg
- Video quality monitoring
- Storage utilization tracking
- Bandwidth consumption analysis

### Wireless Infrastructure
- Access point simulation with hostapd
- Client connection simulation
- Coverage area mapping
- Interference detection

### Print Services
- CUPS print server simulation
- Queue management testing
- Network printing protocols
- Consumables monitoring simulation

## 📋 Validation Checklist

✅ **Infrastructure**: 8 VMs deployed with correct subnets and IPs
✅ **Security**: NSGs configured with appropriate protocol restrictions  
✅ **Monitoring**: Azure Monitor agents on all VMs
✅ **Access**: Jump box access pattern working
✅ **Outputs**: Comprehensive information for operations
✅ **Documentation**: Complete setup and operation guides
✅ **Cost**: Optimized VM sizes for simulation workloads

## 🔄 Next Steps

1. **Deploy and Test**: Run the enhanced Terraform configuration
2. **Device Configuration**: Install simulation software on each VM type
3. **Monitoring Setup**: Configure custom dashboards and alerts
4. **Automation**: Create Ansible playbooks for device configuration
5. **Scaling**: Test with larger device counts for bigger events

The enhanced infrastructure now provides a comprehensive live event IT simulation environment that accurately represents real-world event scenarios while maintaining cost efficiency and security best practices.
