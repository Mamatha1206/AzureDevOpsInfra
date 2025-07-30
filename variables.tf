# infrastructure/variables.tf

# Global Settings
variable "project_prefix" {
  description = "A short prefix for naming resources to ensure uniqueness."
  type        = string
  default     = "mamatha"
}

variable "location_a" {
  description = "Primary Azure region (Active Cluster)."
  type        = string
  default     = "North Central US"
}

variable "location_b" {
  description = "Secondary Azure region (Passive/DR Cluster)."
  type        = string
  default     = "South India"
}

# Resource Groups
variable "resource_group_name_a" {
  description = "The name of the primary resource group."
  type        = string
  default     = "mamatha-rg"
}

variable "resource_group_name_b" {
  description = "The name of the secondary resource group."
  type        = string
  default     = "mamatha-rg-b"
}

# Networking
variable "vnet_address_space_a" {
  description = "Address space for the primary VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vnet_address_space_b" {
  description = "Address space for the secondary VNet."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix_a" {
  description = "Address prefix for AKS subnet in Region A."
  type        = list(string)
  default     = ["10.0.0.0/22"]
}

variable "aks_subnet_prefix_b" {
  description = "Address prefix for AKS subnet in Region B."
  type        = list(string)
  default     = ["10.10.0.0/22"]
}

# Node Configuration
variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool."
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D4ds_v4"
}

# ACR Configuration
variable "acr_sku" {
  description = "SKU for Azure Container Registry (Basic, Standard, Premium)."
  type        = string
  default     = "Premium"
}

# Traffic Manager Configuration
variable "enable_tm" {
  description = "Enable Traffic Manager setup."
  type        = bool
  default     = false
}

variable "ingress_ip" {
  description = "IP address of the active ingress controller."
  type        = string
  default     = ""
}

variable "backup_ingress_ip" {
  description = "IP address of the passive/backup ingress controller."
  type        = string
  default     = ""
}
