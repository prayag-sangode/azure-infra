resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${random_pet.rg_name.id}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "aci-delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

resource "random_string" "container_name" {
  length  = 25
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_container_group" "container" {
  name                = "${var.container_group_name_prefix}-${random_string.container_name.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  restart_policy      = var.restart_policy
  subnet_ids          = [azurerm_subnet.subnet.id] # Use the subnet ID directly here

  container {
    name   = "${var.container_name_prefix}-${random_string.container_name.result}"
    image  = var.image
    cpu    = var.cpu_cores
    memory = var.memory_in_gb

    ports {
      port     = var.port
      protocol = "TCP"
    }
  }
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location for all resources."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix for the resource group name."
}

variable "container_group_name_prefix" {
  type        = string
  default     = "acigroup"
  description = "Prefix for the container group name."
}

variable "container_name_prefix" {
  type        = string
  default     = "aci"
  description = "Prefix for the container name."
}

variable "image" {
  type        = string
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld"
  description = "Container image to deploy."
}

variable "port" {
  type        = number
  default     = 80
  description = "Port to open on the container."
}

variable "cpu_cores" {
  type        = number
  default     = 1
  description = "CPU cores to allocate to the container."
}

variable "memory_in_gb" {
  type        = number
  default     = 2
  description = "Memory to allocate to the container (in GB)."
}

variable "restart_policy" {
  type        = string
  default     = "Always"
  description = "Container restart policy."
  validation {
    condition     = contains(["Always", "Never", "OnFailure"], var.restart_policy)
    error_message = "Restart policy must be one of: Always, Never, OnFailure."
  }
}

output "container_ipv4_address" {
  value = azurerm_container_group.container.ip_address
}
