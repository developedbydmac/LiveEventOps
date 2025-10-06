# Outputs for LiveEventOps Terraform Configuration

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.liveeventops.name
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.liveeventops.location
}

output "virtual_network_name" {
  description = "Name of the created virtual network"
  value       = azurerm_virtual_network.liveeventops_vnet.name
}

output "virtual_network_id" {
  description = "ID of the created virtual network"
  value       = azurerm_virtual_network.liveeventops_vnet.id
}

output "subnet_ids" {
  description = "IDs of all created subnets"
  value = {
    management = azurerm_subnet.management.id
    camera     = azurerm_subnet.camera.id
    wireless   = azurerm_subnet.wireless.id
    dmz        = azurerm_subnet.dmz.id
  }
}

output "management_vm_public_ip" {
  description = "Public IP address of the management VM"
  value       = azurerm_public_ip.management_vm_pip.ip_address
}

output "management_vm_private_ip" {
  description = "Private IP address of the management VM"
  value       = azurerm_network_interface.management_vm_nic.private_ip_address
}

output "management_vm_fqdn" {
  description = "FQDN of the management VM"
  value       = azurerm_public_ip.management_vm_pip.fqdn
}

output "storage_account_name" {
  description = "Name of the created storage account"
  value       = azurerm_storage_account.liveeventops_storage.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.liveeventops_storage.primary_blob_endpoint
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.liveeventops_logs.id
}

output "log_analytics_workspace_customer_id" {
  description = "Customer ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH command to connect to the management VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.management_vm_pip.ip_address}"
}

output "environment_summary" {
  description = "Summary of the deployed environment"
  value = {
    project            = "LiveEventOps"
    environment        = var.environment
    resource_group     = azurerm_resource_group.liveeventops.name
    location           = azurerm_resource_group.liveeventops.location
    vnet_address_space = azurerm_virtual_network.liveeventops_vnet.address_space
    subnet_count       = 4
    vm_count           = 1 + var.camera_count + var.wireless_count + var.printer_count
    storage_accounts   = 1
    device_counts = {
      cameras      = var.camera_count
      wireless_aps = var.wireless_count
      printers     = var.printer_count
    }
  }
}

# Device VM IP addresses
output "camera_vm_ips" {
  description = "Private IP addresses of camera VMs"
  value = {
    for i in range(var.camera_count) : "camera-${i + 1}" => azurerm_network_interface.camera_vm_nic[i].private_ip_address
  }
}

output "wireless_vm_ips" {
  description = "Private IP addresses of wireless AP VMs"
  value = {
    for i in range(var.wireless_count) : "wireless-ap-${i + 1}" => azurerm_network_interface.wireless_vm_nic[i].private_ip_address
  }
}

output "printer_vm_ips" {
  description = "Private IP addresses of printer VMs"
  value = {
    for i in range(var.printer_count) : "printer-${i + 1}" => azurerm_network_interface.printer_vm_nic[i].private_ip_address
  }
}

# Device VM names
output "camera_vm_names" {
  description = "Names of camera VMs"
  value       = [for vm in azurerm_linux_virtual_machine.camera_vm : vm.name]
}

output "wireless_vm_names" {
  description = "Names of wireless AP VMs"
  value       = [for vm in azurerm_linux_virtual_machine.wireless_vm : vm.name]
}

output "printer_vm_names" {
  description = "Names of printer VMs"
  value       = [for vm in azurerm_linux_virtual_machine.printer_vm : vm.name]
}

# SSH connection commands for device VMs
output "device_ssh_commands" {
  description = "SSH commands to connect to device VMs via management VM"
  value = {
    cameras = {
      for i in range(var.camera_count) : "camera-${i + 1}" => "ssh -J ${var.admin_username}@${azurerm_public_ip.management_vm_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.camera_vm_nic[i].private_ip_address}"
    }
    wireless_aps = {
      for i in range(var.wireless_count) : "wireless-ap-${i + 1}" => "ssh -J ${var.admin_username}@${azurerm_public_ip.management_vm_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.wireless_vm_nic[i].private_ip_address}"
    }
    printers = {
      for i in range(var.printer_count) : "printer-${i + 1}" => "ssh -J ${var.admin_username}@${azurerm_public_ip.management_vm_pip.ip_address} ${var.admin_username}@${azurerm_network_interface.printer_vm_nic[i].private_ip_address}"
    }
  }
}

# Network summary
output "network_summary" {
  description = "Summary of network configuration"
  value = {
    vnet_name = azurerm_virtual_network.liveeventops_vnet.name
    subnets = {
      management = {
        name     = azurerm_subnet.management.name
        cidr     = azurerm_subnet.management.address_prefixes[0]
        vm_count = 1
      }
      camera = {
        name     = azurerm_subnet.camera.name
        cidr     = azurerm_subnet.camera.address_prefixes[0]
        vm_count = var.camera_count
      }
      wireless = {
        name     = azurerm_subnet.wireless.name
        cidr     = azurerm_subnet.wireless.address_prefixes[0]
        vm_count = var.wireless_count
      }
      dmz = {
        name     = azurerm_subnet.dmz.name
        cidr     = azurerm_subnet.dmz.address_prefixes[0]
        vm_count = var.printer_count
      }
    }
  }
}

# Monitoring configuration
output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value = {
    log_analytics_workspace = azurerm_log_analytics_workspace.liveeventops_logs.name
    workspace_id            = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
    data_collection_rule    = azurerm_monitor_data_collection_rule.device_monitoring.name
    monitored_vms           = 1 + var.camera_count + var.wireless_count + var.printer_count
  }
}

# Key Vault outputs
output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.liveeventops.name
}

output "key_vault_id" {
  description = "ID of the Azure Key Vault"
  value       = azurerm_key_vault.liveeventops.id
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.liveeventops.vault_uri
}

output "key_vault_tenant_id" {
  description = "Tenant ID associated with the Key Vault"
  value       = azurerm_key_vault.liveeventops.tenant_id
}
