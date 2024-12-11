# Resource Group
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

# Virtual Network and Subnet with Delegation
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
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Container Group
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
  subnet_ids          = [azurerm_subnet.subnet.id]  # Subnet for private IP
  ip_address_type     = "Private"                  # Must use private IP for subnet

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

# Application Gateway - Public Frontend IP
resource "azurerm_public_ip" "app_gateway_ip" {
  name                = "app-gateway-ip-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                  = "Standard"
}

# Application Gateway Backend Pool (pointing to the container's private IP)
resource "azurerm_application_gateway_backend_address_pool" "backend_pool" {
  name                 = "backend-pool-${random_pet.rg_name.id}"
  resource_group_name  = azurerm_resource_group.rg.name
  application_gateway_name = azurerm_application_gateway.app_gateway.name

  backend_addresses {
    ip_address = azurerm_container_group.container.ip_address
  }
}

# Application Gateway HTTP Settings
resource "azurerm_application_gateway_http_settings" "http_settings" {
  name                            = "http-settings-${random_pet.rg_name.id}"
  resource_group_name             = azurerm_resource_group.rg.name
  application_gateway_name       = azurerm_application_gateway.app_gateway.name
  port                            = var.port
  protocol                        = "Http"
  cookie_based_affinity           = "Disabled"
}

# Application Gateway Listener (to listen on port 80)
resource "azurerm_application_gateway_listener" "listener" {
  name                                = "listener-${random_pet.rg_name.id}"
  resource_group_name                 = azurerm_resource_group.rg.name
  application_gateway_name           = azurerm_application_gateway.app_gateway.name
  frontend_ip_configuration_id      = azurerm_public_ip.app_gateway_ip.id
  frontend_port {
    name = "frontend-port"
    port = 80
  }
  protocol = "Http"
}

# Application Gateway URL Path-Based Routing (for routing to container)
resource "azurerm_application_gateway_url_path_map" "url_path_map" {
  name                                = "path-map-${random_pet.rg_name.id}"
  resource_group_name                 = azurerm_resource_group.rg.name
  application_gateway_name           = azurerm_application_gateway.app_gateway.name
  default_backend_address_pool_id    = azurerm_application_gateway_backend_address_pool.backend_pool.id
  default_backend_http_settings_id   = azurerm_application_gateway_http_settings.http_settings.id

  default_backend {
    backend_address_pool_id         = azurerm_application_gateway_backend_address_pool.backend_pool.id
    backend_http_settings_id        = azurerm_application_gateway_http_settings.http_settings.id
  }
}

# Application Gateway Resource
resource "azurerm_application_gateway" "app_gateway" {
  name                              = "app-gateway-${random_pet.rg_name.id}"
  location                          = azurerm_resource_group.rg.location
  resource_group_name               = azurerm_resource_group.rg.name
  sku                               = "Standard_v2"
  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = azurerm_subnet.subnet.id
  }
  gateway_type                      = "Standard_v2"
  frontend_ip_configuration {
    name                                 = "frontend-ip-config"
    public_ip_address_id                = azurerm_public_ip.app_gateway_ip.id
  }

  backend_address_pool {
    name                                = "backend-pool"
    backend_addresses {
      ip_address = azurerm_container_group.container.ip_address
    }
  }

  backend_http_settings {
    name                        = "http-settings"
    port                        = var.port
    protocol                    = "Http"
    cookie_based_affinity       = "Disabled"
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_id  = azurerm_public_ip.app_gateway_ip.id
    frontend_port_id              = azurerm_application_gateway_listener.listener.id
    protocol                      = "Http"
  }

  url_path_map {
    name = "url-path-map"
    default_backend_address_pool_id = azurerm_application_gateway_backend_address_pool.backend_pool.id
    default_backend_http_settings_id = azurerm_application_gateway_http_settings.http_settings.id
    default_backend {
      backend_address_pool_id = azurerm_application_gateway_backend_address_pool.backend_pool.id
      backend_http_settings_id = azurerm_application_gateway_http_settings.http_settings.id
    }
  }
}

# Variables (if not already defined)
variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location for all resources."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random value so name is unique in your Azure subscription."
}

variable "container_group_name_prefix" {
  type        = string
  default     = "acigroup"
  description = "Prefix of the container group name that's combined with a random value so name is unique in your Azure subscription."
}

variable "container_name_prefix" {
  type        = string
  default     = "aci"
  description = "Prefix of the container name that's combined with a random value so name is unique in your Azure subscription."
}

variable "image" {
  type        = string
  default     = "mcr.microsoft.com/aspnetcore/samples"
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
  description = "The number of CPU cores to allocate to the container."
}

variable "memory_in_gb" {
  type        = number
  default     = 2
  description = "The amount of memory to allocate to the container in gigabytes."
}

variable "restart_policy" {
  type        = string
  default     = "Always"
  description = "The behavior of Azure runtime if container has stopped."
}

# Outputs
output "container_ipv4_address" {
  value = azurerm_container_group.container.ip_address
}
