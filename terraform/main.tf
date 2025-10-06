# LiveEventOps Terraform Configuration
# Main infrastructure provisioning for Azure resources

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Remote state configuration for Azure Blob Storage
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstate${random_string.storage_suffix.result}"
    container_name       = "tfstate"
    key                  = "liveeventops.terraform.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

# Generate random suffix for unique naming
resource "random_string" "resource_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "liveeventops" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment  = var.environment
    project      = "LiveEventOps"
    managed_by   = "terraform"
    created_date = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Virtual Network
resource "azurerm_virtual_network" "liveeventops_vnet" {
  name                = "${var.project_name}-vnet-${random_string.resource_suffix.result}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Management Subnet
resource "azurerm_subnet" "management" {
  name                 = "management-subnet"
  resource_group_name  = azurerm_resource_group.liveeventops.name
  virtual_network_name = azurerm_virtual_network.liveeventops_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Camera Subnet
resource "azurerm_subnet" "camera" {
  name                 = "camera-subnet"
  resource_group_name  = azurerm_resource_group.liveeventops.name
  virtual_network_name = azurerm_virtual_network.liveeventops_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Wireless Subnet
resource "azurerm_subnet" "wireless" {
  name                 = "wireless-subnet"
  resource_group_name  = azurerm_resource_group.liveeventops.name
  virtual_network_name = azurerm_virtual_network.liveeventops_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# DMZ Subnet
resource "azurerm_subnet" "dmz" {
  name                 = "dmz-subnet"
  resource_group_name  = azurerm_resource_group.liveeventops.name
  virtual_network_name = azurerm_virtual_network.liveeventops_vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Network Security Group for Management Subnet
resource "azurerm_network_security_group" "management_nsg" {
  name                = "management-nsg-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Associate Network Security Group to Management Subnet
resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management_nsg.id
}

# Public IP for Management VM
resource "azurerm_public_ip" "management_vm_pip" {
  name                = "management-vm-pip-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Interface for Management VM
resource "azurerm_network_interface" "management_vm_nic" {
  name                = "management-vm-nic-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management_vm_pip.id
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Management Virtual Machine
resource "azurerm_linux_virtual_machine" "management_vm" {
  name                = "management-vm-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.management_vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    role        = "management"
  }
}

# Storage Account for VM diagnostics and general storage
resource "azurerm_storage_account" "liveeventops_storage" {
  name                     = "liveeventops${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.liveeventops.name
  location                 = azurerm_resource_group.liveeventops.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Storage Container for video content
resource "azurerm_storage_container" "video_content" {
  name                  = "video-content"
  storage_account_id    = azurerm_storage_account.liveeventops_storage.id
  container_access_type = "private"
}

# Storage Container for configuration files
resource "azurerm_storage_container" "configurations" {
  name                  = "configurations"
  storage_account_id    = azurerm_storage_account.liveeventops_storage.id
  container_access_type = "private"
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "liveeventops_logs" {
  name                = "liveeventops-logs-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Security Group for Camera Subnet
resource "azurerm_network_security_group" "camera_nsg" {
  name                = "camera-nsg-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  security_rule {
    name                       = "RTSP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "554"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-Cameras"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH-Internal"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Security Group for Wireless Subnet
resource "azurerm_network_security_group" "wireless_nsg" {
  name                = "wireless-nsg-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  security_rule {
    name                       = "CAPWAP-Control"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5246"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "CAPWAP-Data"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5247"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH-Wireless"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Security Group for DMZ Subnet (Printers)
resource "azurerm_network_security_group" "dmz_nsg" {
  name                = "dmz-nsg-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  security_rule {
    name                       = "IPP-Printing"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "631"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "LPD-Printing"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "515"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH-DMZ"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Associate NSGs to Subnets
resource "azurerm_subnet_network_security_group_association" "camera" {
  subnet_id                 = azurerm_subnet.camera.id
  network_security_group_id = azurerm_network_security_group.camera_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "wireless" {
  subnet_id                 = azurerm_subnet.wireless.id
  network_security_group_id = azurerm_network_security_group.wireless_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz_nsg.id
}

# Camera VMs (2 units)
resource "azurerm_network_interface" "camera_vm_nic" {
  count               = var.camera_count
  name                = "camera-${count.index + 1}-nic-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.camera.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.${10 + count.index}"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    device_type = "camera"
  }
}

resource "azurerm_linux_virtual_machine" "camera_vm" {
  count               = var.camera_count
  name                = "camera-${count.index + 1}-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  size                = var.device_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.camera_vm_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    role        = "camera"
    device_id   = "camera-${count.index + 1}"
  }
}

# Wireless Access Point VMs (3 units)
resource "azurerm_network_interface" "wireless_vm_nic" {
  count               = var.wireless_count
  name                = "wireless-ap-${count.index + 1}-nic-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.wireless.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.3.${10 + count.index}"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    device_type = "wireless_ap"
  }
}

resource "azurerm_linux_virtual_machine" "wireless_vm" {
  count               = var.wireless_count
  name                = "wireless-ap-${count.index + 1}-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  size                = var.device_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.wireless_vm_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    role        = "wireless_ap"
    device_id   = "wireless-ap-${count.index + 1}"
  }
}

# Printer VMs (2 units)
resource "azurerm_network_interface" "printer_vm_nic" {
  count               = var.printer_count
  name                = "printer-${count.index + 1}-nic-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.4.${10 + count.index}"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    device_type = "printer"
  }
}

resource "azurerm_linux_virtual_machine" "printer_vm" {
  count               = var.printer_count
  name                = "printer-${count.index + 1}-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  size                = var.device_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.printer_vm_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
    role        = "printer"
    device_id   = "printer-${count.index + 1}"
  }
}

# Azure Monitor Agent Extension for Management VM
resource "azurerm_virtual_machine_extension" "management_vm_monitor" {
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.management_vm.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"

  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
  })

  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.liveeventops_logs.primary_shared_key
  })

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Azure Monitor Agent Extension for Camera VMs
resource "azurerm_virtual_machine_extension" "camera_vm_monitor" {
  count                = var.camera_count
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.camera_vm[count.index].id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"

  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
  })

  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.liveeventops_logs.primary_shared_key
  })

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Azure Monitor Agent Extension for Wireless VMs
resource "azurerm_virtual_machine_extension" "wireless_vm_monitor" {
  count                = var.wireless_count
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.wireless_vm[count.index].id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"

  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
  })

  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.liveeventops_logs.primary_shared_key
  })

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Azure Monitor Agent Extension for Printer VMs
resource "azurerm_virtual_machine_extension" "printer_vm_monitor" {
  count                = var.printer_count
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.printer_vm[count.index].id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"

  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.liveeventops_logs.workspace_id
  })

  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.liveeventops_logs.primary_shared_key
  })

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Data Collection Rule for device monitoring
resource "azurerm_monitor_data_collection_rule" "device_monitoring" {
  name                = "device-monitoring-dcr-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.liveeventops_logs.id
      name                  = "log-analytics-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["log-analytics-destination"]
  }

  data_sources {
    syslog {
      facility_names = ["*"]
      log_levels     = ["*"]
      name           = "syslog-datasource"
      streams        = ["Microsoft-Syslog"]
    }

    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\Network Interface(*)\\Bytes Total/sec"
      ]
      name = "perfcounter-datasource"
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}
