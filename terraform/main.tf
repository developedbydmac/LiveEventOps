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
    azd-env-name = var.environment
  }
}

# Azure Key Vault for secure secret management
resource "azurerm_key_vault" "liveeventops" {
  name                = "${var.project_name}-kv-${random_string.resource_suffix.result}"
  location            = azurerm_resource_group.liveeventops.location
  resource_group_name = azurerm_resource_group.liveeventops.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable soft delete and purge protection for production security
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = var.key_vault_purge_protection_enabled

  # Network access rules for security
  network_acls {
    default_action = var.key_vault_network_default_action
    bypass         = "AzureServices"
  }

  # Enable RBAC for access control
  enabled_for_deployment = true
  enabled_for_template_deployment = true

  tags = {
    environment  = var.environment
    project      = "LiveEventOps"
    managed_by   = "terraform"
    purpose      = "secret-management"
    azd-env-name = var.environment
  }
}

# Key Vault Access Policy for Terraform Service Principal
resource "azurerm_key_vault_access_policy" "terraform_sp" {
  key_vault_id = azurerm_key_vault.liveeventops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Update",
    "Import",
    "Backup",
    "Restore",
    "Recover"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Update",
    "Import"
  ]
}

# Additional Key Vault access policies for other users/service principals
resource "azurerm_key_vault_access_policy" "additional" {
  count = length(var.additional_key_vault_access_policies)

  key_vault_id = azurerm_key_vault.liveeventops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.additional_key_vault_access_policies[count.index].object_id

  secret_permissions      = var.additional_key_vault_access_policies[count.index].secret_permissions
  key_permissions        = var.additional_key_vault_access_policies[count.index].key_permissions
  certificate_permissions = var.additional_key_vault_access_policies[count.index].certificate_permissions
}

# Key Vault secrets for VM authentication and monitoring
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "vm-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.liveeventops.id

  depends_on = [azurerm_key_vault_access_policy.terraform_sp]

  tags = {
    purpose = "vm-authentication"
  }
}

resource "azurerm_key_vault_secret" "ssh_public_key" {
  name         = "ssh-public-key"
  value        = var.ssh_public_key
  key_vault_id = azurerm_key_vault.liveeventops.id

  depends_on = [azurerm_key_vault_access_policy.terraform_sp]

  tags = {
    purpose = "vm-authentication"
  }
}

resource "azurerm_key_vault_secret" "webhook_url" {
  name         = "monitoring-webhook-url"
  value        = var.webhook_url != "" ? var.webhook_url : "https://placeholder.example.com/webhook"
  key_vault_id = azurerm_key_vault.liveeventops.id

  depends_on = [azurerm_key_vault_access_policy.terraform_sp]

  tags = {
    purpose = "monitoring-integration"
  }
}

resource "azurerm_key_vault_secret" "alert_email" {
  name         = "monitoring-alert-email"
  value        = var.alert_email
  key_vault_id = azurerm_key_vault.liveeventops.id

  depends_on = [azurerm_key_vault_access_policy.terraform_sp]

  tags = {
    purpose = "monitoring-alerts"
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

# Action Group for Alert Notifications
resource "azurerm_monitor_action_group" "vm_alerts" {
  name                = "vm-alerts-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.liveeventops.name
  short_name          = "vmalerts"

  webhook_receiver {
    name                    = "github-actions-webhook"
    service_uri             = var.webhook_url
    use_common_alert_schema = true
  }

  email_receiver {
    name          = "operations-team"
    email_address = var.alert_email
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Diagnostic Settings for Management VM
resource "azurerm_monitor_diagnostic_setting" "management_vm_diagnostics" {
  name                       = "management-vm-diagnostics"
  target_resource_id         = azurerm_linux_virtual_machine.management_vm.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops_logs.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Diagnostic Settings for Camera VMs
resource "azurerm_monitor_diagnostic_setting" "camera_vm_diagnostics" {
  count                      = var.camera_count
  name                       = "camera-${count.index + 1}-diagnostics"
  target_resource_id         = azurerm_linux_virtual_machine.camera_vm[count.index].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops_logs.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Diagnostic Settings for Wireless VMs
resource "azurerm_monitor_diagnostic_setting" "wireless_vm_diagnostics" {
  count                      = var.wireless_count
  name                       = "wireless-${count.index + 1}-diagnostics"
  target_resource_id         = azurerm_linux_virtual_machine.wireless_vm[count.index].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops_logs.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Diagnostic Settings for Printer VMs
resource "azurerm_monitor_diagnostic_setting" "printer_vm_diagnostics" {
  count                      = var.printer_count
  name                       = "printer-${count.index + 1}-diagnostics"
  target_resource_id         = azurerm_linux_virtual_machine.printer_vm[count.index].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops_logs.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Security Group Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "nsg_diagnostics" {
  for_each = {
    management = azurerm_network_security_group.management_nsg.id
    camera     = azurerm_network_security_group.camera_nsg.id
    wireless   = azurerm_network_security_group.wireless_nsg.id
    dmz        = azurerm_network_security_group.dmz_nsg.id
  }

  name                       = "${each.key}-nsg-diagnostics"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.liveeventops_logs.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# VM CPU Alert Rules
resource "azurerm_monitor_metric_alert" "vm_cpu_alert" {
  for_each = merge(
    { for i in range(1) : "management" => azurerm_linux_virtual_machine.management_vm.id },
    { for i in range(var.camera_count) : "camera-${i + 1}" => azurerm_linux_virtual_machine.camera_vm[i].id },
    { for i in range(var.wireless_count) : "wireless-${i + 1}" => azurerm_linux_virtual_machine.wireless_vm[i].id },
    { for i in range(var.printer_count) : "printer-${i + 1}" => azurerm_linux_virtual_machine.printer_vm[i].id }
  )

  name                = "${each.key}-high-cpu"
  resource_group_name = azurerm_resource_group.liveeventops.name
  scopes              = [each.value]
  description         = "Alert when CPU usage exceeds 80% for ${each.key} VM"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.vm_alerts.id
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# VM Memory Alert Rules
resource "azurerm_monitor_metric_alert" "vm_memory_alert" {
  for_each = merge(
    { for i in range(1) : "management" => azurerm_linux_virtual_machine.management_vm.id },
    { for i in range(var.camera_count) : "camera-${i + 1}" => azurerm_linux_virtual_machine.camera_vm[i].id },
    { for i in range(var.wireless_count) : "wireless-${i + 1}" => azurerm_linux_virtual_machine.wireless_vm[i].id },
    { for i in range(var.printer_count) : "printer-${i + 1}" => azurerm_linux_virtual_machine.printer_vm[i].id }
  )

  name                = "${each.key}-low-memory"
  resource_group_name = azurerm_resource_group.liveeventops.name
  scopes              = [each.value]
  description         = "Alert when available memory is below 100MB for ${each.key} VM"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 104857600 # 100MB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.vm_alerts.id
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# VM Heartbeat Alert Rules
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_heartbeat_alert" {
  for_each = merge(
    { for i in range(1) : "management" => "management-vm-${random_string.resource_suffix.result}" },
    { for i in range(var.camera_count) : "camera-${i + 1}" => "camera-${i + 1}-${random_string.resource_suffix.result}" },
    { for i in range(var.wireless_count) : "wireless-${i + 1}" => "wireless-ap-${i + 1}-${random_string.resource_suffix.result}" },
    { for i in range(var.printer_count) : "printer-${i + 1}" => "printer-${i + 1}-${random_string.resource_suffix.result}" }
  )

  name                = "${each.key}-heartbeat-missing"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  description         = "Alert when ${each.key} VM heartbeat is missing"
  severity            = 0

  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
  scopes               = [azurerm_log_analytics_workspace.liveeventops_logs.id]

  criteria {
    query = <<-QUERY
      Heartbeat
      | where Computer == "${each.value}"
      | summarize LastHeartbeat = max(TimeGenerated)
      | where LastHeartbeat < ago(10m)
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.vm_alerts.id]
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}

# Network Security Group Alert Rules
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "nsg_blocked_traffic_alert" {
  for_each = {
    management = "management-nsg"
    camera     = "camera-nsg"
    wireless   = "wireless-nsg"
    dmz        = "dmz-nsg"
  }

  name                = "${each.key}-blocked-traffic"
  resource_group_name = azurerm_resource_group.liveeventops.name
  location            = azurerm_resource_group.liveeventops.location
  description         = "Alert when ${each.key} NSG blocks significant traffic"
  severity            = 2

  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes               = [azurerm_log_analytics_workspace.liveeventops_logs.id]

  criteria {
    query = <<-QUERY
      AzureNetworkAnalytics_CL
      | where NSGName_s contains "${each.value}"
      | where FlowStatus_s == "D"
      | summarize BlockedConnections = count()
      | where BlockedConnections > 10
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.vm_alerts.id]
  }

  tags = {
    environment = var.environment
    project     = "LiveEventOps"
    managed_by  = "terraform"
  }
}
