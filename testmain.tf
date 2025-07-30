terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
  }

  backend "azurerm" {
    resource_group_name  = "mamatha-rg"
    storage_account_name = "mamathasg"
    container_name       = "tfstate1"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Fetch current client configuration
data "azurerm_client_config" "current" {}

# --- Resource Groups ---
resource "azurerm_resource_group" "rg_a" {
  name     = var.resource_group_name_a
  location = var.location_a
  tags = {
    environment = "prod-active"
  }
}

resource "azurerm_resource_group" "rg_b" {
  name     = var.resource_group_name_b
  location = var.location_b
  tags = {
    environment = "prod-passive"
  }
}

# --- Networking Setup (Region A - Active) ---
resource "azurerm_virtual_network" "vnet_a" {
  name                = "${var.project_prefix}-vnet-${azurerm_resource_group.rg_a.location}"
  address_space       = var.vnet_address_space_a
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
}

resource "azurerm_subnet" "aks_subnet_a" {
  name                 = "${var.project_prefix}-aks-subnet-${azurerm_resource_group.rg_a.location}"
  resource_group_name  = azurerm_resource_group.rg_a.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = var.aks_subnet_prefix_a
}

# --- Networking Setup (Region B - Passive) ---
resource "azurerm_virtual_network" "vnet_b" {
  name                = "${var.project_prefix}-vnet-${azurerm_resource_group.rg_b.location}"
  address_space       = var.vnet_address_space_b
  location            = azurerm_resource_group.rg_b.location
  resource_group_name = azurerm_resource_group.rg_b.name
}

resource "azurerm_subnet" "aks_subnet_b" {
  name                 = "${var.project_prefix}-aks-subnet-${azurerm_resource_group.rg_b.location}"
  resource_group_name  = azurerm_resource_group.rg_b.name
  virtual_network_name = azurerm_virtual_network.vnet_b.name
  address_prefixes     = var.aks_subnet_prefix_b
}

# --- Azure Container Registry (ACR) ---
resource "azurerm_container_registry" "acr" {
  name                = "${var.project_prefix}acr"
  resource_group_name = azurerm_resource_group.rg_a.name
  location            = azurerm_resource_group.rg_a.location
  sku                 = "Premium" # Enables geo-replication if needed
  admin_enabled       = false
}

# --- Azure Kubernetes Service (AKS) Cluster (Region A - Active) ---
resource "azurerm_kubernetes_cluster" "aks_cluster_a" {
  name                = "${var.project_prefix}-aks-cluster"
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
  dns_prefix          = "${var.project_prefix}-aks-a"

  default_node_pool {
    name                = "systempool"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet_a.id
    os_disk_size_gb     = 30
    type                = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    service_cidr       = "10.1.0.0/16"
    dns_service_ip     = "10.1.0.10"
    load_balancer_sku  = "standard"
  }

  role_based_access_control_enabled = true

  web_app_routing {}

  tags = {
    environment = "prod-active"
  }
}

# Grant AKS ACR Pull Permissions (Region A)
resource "azurerm_role_assignment" "aks_acr_pull_a" {
  principal_id         = azurerm_kubernetes_cluster.aks_cluster_a.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# --- Azure Kubernetes Service (AKS) Cluster (Region B - Passive) ---
resource "azurerm_kubernetes_cluster" "aks_cluster_b" {
  name                = "${var.project_prefix}-aks-cluster-b"
  location            = azurerm_resource_group.rg_b.location
  resource_group_name = azurerm_resource_group.rg_b.name
  dns_prefix          = "${var.project_prefix}-aks-b"

  default_node_pool {
    name                = "systempool"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet_b.id
    os_disk_size_gb     = 30
    type                = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    service_cidr       = "10.2.0.0/16"
    dns_service_ip     = "10.2.0.10"
    load_balancer_sku  = "standard"
  }

  role_based_access_control_enabled = true

  web_app_routing {}

  tags = {
    environment = "prod-passive"
  }
}

# Grant AKS ACR Pull Permissions (Region B)
resource "azurerm_role_assignment" "aks_acr_pull_b" {
  principal_id         = azurerm_kubernetes_cluster.aks_cluster_b.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# --- Traffic Manager Profile ---
resource "azurerm_traffic_manager_profile" "tm_profile" {
  count               = var.enable_tm ? 1 : 0
  name                = "${var.project_prefix}-tm-profile"
  resource_group_name = azurerm_resource_group.rg_a.name

  profile_status         = "Enabled"
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${var.project_prefix}-app"
    ttl           = 30
  }

  monitor_config {
    protocol = "HTTP"
    port     = 80
    path     = "/"
  }

  tags = {
    environment = "production"
  }
}

# --- Traffic Manager Endpoints ---
resource "azurerm_traffic_manager_external_endpoint" "primary_ingress" {
  count              = var.enable_tm && var.ingress_ip != "" ? 1 : 0
  name               = "aks-ingress-endpoint"
  profile_id         = azurerm_traffic_manager_profile.tm_profile[0].id
  target             = var.ingress_ip
  endpoint_location  = var.location_a
  priority           = 1
}

resource "azurerm_traffic_manager_external_endpoint" "secondary_ingress" {
  count              = var.enable_tm && var.backup_ingress_ip != "" ? 1 : 0
  name               = "aks-ingress-endpoint-b"
  profile_id         = azurerm_traffic_manager_profile.tm_profile[0].id
  target             = var.backup_ingress_ip
  endpoint_location  = var.location_b
  priority           = 2
}
