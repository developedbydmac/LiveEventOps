# Enhanced Infrastructure with Device Simulation VMs

## Overview

The Terraform configuration has been enhanced to include Azure VMs that simulate live event IT devices including cameras, wireless access points, and printers. Each device type is deployed in its appropriate subnet with static IP assignments and comprehensive monitoring.

## Infrastructure Summary

### Virtual Machines Deployed

| Device Type | Count | Subnet | IP Range | VM Size |
|-------------|-------|--------|----------|---------|
| Management VM | 1 | Management (10.0.1.0/24) | 10.0.1.4 (dynamic) | Standard_B2s |
| Camera VMs | 2 (configurable) | Camera (10.0.2.0/24) | 10.0.2.10-11 | Standard_B1s |
| Wireless AP VMs | 3 (configurable) | Wireless (10.0.3.0/24) | 10.0.3.10-12 | Standard_B1s |
| Printer VMs | 2 (configurable) | DMZ (10.0.4.0/24) | 10.0.4.10-11 | Standard_B1s |

### Network Security Groups

#### Management NSG
- SSH (22) - Allow from anywhere
- HTTP (80) - Allow from anywhere  
- HTTPS (443) - Allow from anywhere

#### Camera NSG
- RTSP (554) - Allow from VNet (10.0.0.0/16)
- HTTP (80) - Allow from VNet
- SSH (22) - Allow from Management subnet only

#### Wireless NSG
- CAPWAP Control (5246/UDP) - Allow from VNet
- CAPWAP Data (5247/UDP) - Allow from VNet
- SSH (22) - Allow from Management subnet only

#### DMZ NSG (Printers)
- IPP Printing (631) - Allow from VNet
- LPD Printing (515) - Allow from VNet
- SSH (22) - Allow from Management subnet only

## Device Simulation Details

### Camera VMs
- **Purpose**: Simulate IP cameras with video streaming capabilities
- **Network Ports**: RTSP (554) for video streaming, HTTP (80) for configuration
- **Static IPs**: 10.0.2.10, 10.0.2.11
- **Simulation Software**: Can be configured with FFmpeg for RTSP streaming

### Wireless Access Point VMs
- **Purpose**: Simulate wireless controllers and access points
- **Network Ports**: CAPWAP control and data tunnels
- **Static IPs**: 10.0.3.10, 10.0.3.11, 10.0.3.12
- **Simulation Software**: Can run hostapd or similar wireless simulation tools

### Printer VMs
- **Purpose**: Simulate network printers for event documentation
- **Network Ports**: IPP (631) and LPD (515) for print services
- **Static IPs**: 10.0.4.10, 10.0.4.11
- **Simulation Software**: Can run CUPS for print server simulation

## Monitoring and Extensions

### Azure Monitor Agent
All VMs are equipped with Azure Monitor Agent extensions that:
- Collect system logs via syslog
- Monitor performance counters (CPU, Memory, Network)
- Send data to the central Log Analytics workspace
- Enable centralized monitoring and alerting

### Data Collection Rule
A centralized data collection rule captures:
- **Syslog Data**: All facility levels and log levels
- **Performance Counters**: 
  - CPU utilization
  - Available memory
  - Network bytes total/second
- **Sampling Frequency**: 60 seconds for performance data

## Configuration Variables

The device counts and sizes can be customized via variables:

```hcl
# Device count variables
camera_count   = 2    # Number of camera VMs
wireless_count = 3    # Number of wireless AP VMs  
printer_count  = 2    # Number of printer VMs

# VM sizing
vm_size        = "Standard_B2s"  # Management VM
device_vm_size = "Standard_B1s"  # Device VMs
```

## Network Architecture

```
liveeventops-vnet (10.0.0.0/16)
├── management-subnet (10.0.1.0/24)
│   └── management-vm (10.0.1.4 dynamic + public IP)
├── camera-subnet (10.0.2.0/24)  
│   ├── camera-1 (10.0.2.10 static)
│   └── camera-2 (10.0.2.11 static)
├── wireless-subnet (10.0.3.0/24)
│   ├── wireless-ap-1 (10.0.3.10 static)
│   ├── wireless-ap-2 (10.0.3.11 static)
│   └── wireless-ap-3 (10.0.3.12 static)
└── dmz-subnet (10.0.4.0/24)
    ├── printer-1 (10.0.4.10 static)
    └── printer-2 (10.0.4.11 static)
```

## Access Patterns

### Direct Management Access
```bash
# Connect to management VM (has public IP)
ssh azureuser@<management-vm-public-ip>
```

### Jump Box Access to Device VMs
```bash
# Connect to camera VMs via management VM
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.2.10
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.2.11

# Connect to wireless VMs via management VM
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.3.10
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.3.11
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.3.12

# Connect to printer VMs via management VM
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.4.10
ssh -J azureuser@<management-vm-public-ip> azureuser@10.0.4.11
```

## Terraform Outputs

The enhanced configuration provides detailed outputs:

### Device Information
- `camera_vm_ips`: IP addresses of all camera VMs
- `wireless_vm_ips`: IP addresses of all wireless VMs
- `printer_vm_ips`: IP addresses of all printer VMs
- `device_ssh_commands`: Pre-formatted SSH jump commands

### Network Summary
- Complete subnet information with VM counts
- CIDR blocks for each subnet
- Network security group associations

### Monitoring Summary
- Log Analytics workspace details
- Data collection rule information
- Count of monitored VMs

## Cost Estimates (East US)

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| Management VM (Standard_B2s) | 1 | ~$30-40 |
| Device VMs (Standard_B1s) | 7 | ~$70-105 |
| Storage Account | 1 | ~$1-5 |
| Log Analytics Workspace | 1 | ~$5-15 |
| Virtual Network | 1 | Free |
| Public IP | 1 | ~$3-4 |
| **Total Estimated** | | **~$109-169/month** |

## Device Simulation Setup

After deployment, each device type can be configured with appropriate simulation software:

### Camera Setup
```bash
# Install FFmpeg for RTSP streaming simulation
sudo apt update && sudo apt install -y ffmpeg

# Create test RTSP stream
ffmpeg -re -f lavfi -i testsrc2=size=1280x720:rate=30 \
  -f rtsp rtsp://0.0.0.0:554/live
```

### Wireless AP Setup
```bash
# Install hostapd for wireless simulation
sudo apt update && sudo apt install -y hostapd

# Configure virtual wireless interface
# (Configuration files would be deployed via automation)
```

### Printer Setup
```bash
# Install CUPS for print server simulation
sudo apt update && sudo apt install -y cups

# Configure network printing
sudo systemctl enable cups
sudo systemctl start cups
```

## Monitoring Queries

Use these Azure Monitor queries to observe device behavior:

```kusto
// View all device VMs performance
Perf
| where Computer contains "camera" or Computer contains "wireless" or Computer contains "printer"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)

// View device connectivity logs
Syslog
| where Computer contains "camera" or Computer contains "wireless" or Computer contains "printer"
| where SeverityLevel <= 4
| project TimeGenerated, Computer, SeverityLevel, SyslogMessage
```

## Security Considerations

1. **Network Segmentation**: Each device type is isolated in its own subnet
2. **Jump Box Access**: Device VMs are only accessible via management VM
3. **Protocol Restrictions**: NSGs only allow relevant protocols per device type
4. **Monitoring**: All VMs have comprehensive monitoring enabled
5. **SSH Key Authentication**: No password authentication allowed

## Scaling Considerations

To adjust device counts for larger events:

```hcl
# For large events
camera_count   = 8   # More camera coverage
wireless_count = 12  # Increased wireless capacity  
printer_count  = 4   # Additional printing stations

# Consider larger VM sizes for high-load scenarios
device_vm_size = "Standard_B2s"  # More CPU/memory per device
```

This enhanced infrastructure provides a realistic simulation environment for live event IT management scenarios while maintaining cost efficiency and security best practices.
