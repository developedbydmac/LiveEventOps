# Variables for LiveEventOps Terraform Configuration

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "liveeventops-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "liveeventops"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  # This should be provided at runtime or through terraform.tfvars
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access the infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Should be restricted in production
}

variable "vm_admin_password" {
  description = "Admin password for the virtual machine (if not using SSH keys)"
  type        = string
  default     = null
  sensitive   = true
}

# Device count variables
variable "camera_count" {
  description = "Number of camera VMs to deploy"
  type        = number
  default     = 2
}

variable "wireless_count" {
  description = "Number of wireless access point VMs to deploy"
  type        = number
  default     = 3
}

variable "printer_count" {
  description = "Number of printer VMs to deploy"
  type        = number
  default     = 2
}

variable "device_vm_size" {
  description = "Size of the device virtual machines"
  type        = string
  default     = "Standard_B1s"
}

# Monitoring and alerting variables
variable "webhook_url" {
  description = "Webhook URL for GitHub Actions integration"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = "admin@liveeventops.com"
}

# Key Vault configuration variables
variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted Key Vault items"
  type        = number
  default     = 7
  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Soft delete retention days must be between 7 and 90."
  }
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection for Key Vault (recommended for production)"
  type        = bool
  default     = false
}

variable "key_vault_network_default_action" {
  description = "Default action for Key Vault network access rules (Allow or Deny)"
  type        = string
  default     = "Allow"
  validation {
    condition     = contains(["Allow", "Deny"], var.key_vault_network_default_action)
    error_message = "Key Vault network default action must be either 'Allow' or 'Deny'."
  }
}

variable "additional_key_vault_access_policies" {
  description = "Additional access policies for Key Vault (list of object IDs)"
  type = list(object({
    object_id               = string
    secret_permissions      = list(string)
    key_permissions        = list(string)
    certificate_permissions = list(string)
  }))
  default = []
}
