# Resource Group
resource "random_pet" "rg_name_juiceshop" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg_juiceshop" {
  name     = random_pet.rg_name_juiceshop.id
  location = var.resource_group_location
}

# Virtual Network and Subnet with Delegation
resource "azurerm_virtual_network" "vnet_juiceshop" {
  name                = "vnet-${random_pet.rg_name_juiceshop.id}"
  location            = azurerm_resource_group.rg_juiceshop.location
  resource_group_name = azurerm_resource_group.rg_juiceshop.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_juiceshop" {
  name                 = "subnet-${random_pet.rg_name_juiceshop.id}"
  resource_group_name  = azurerm_resource_group.rg_juiceshop.name
  virtual_network_name = azurerm_virtual_network.vnet_juiceshop.name
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
resource "random_string" "container_name_juiceshop" {
  length  = 25
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_container_group" "container_juiceshop" {
  name                = "${var.container_group_name_prefix}-${random_string.container_name_juiceshop.result}"
  location            = azurerm_resource_group.rg_juiceshop.location
  resource_group_name = azurerm_resource_group.rg_juiceshop.name
  os_type             = "Linux"
  restart_policy      = var.restart_policy
  subnet_ids          = [azurerm_subnet.subnet_juiceshop.id]  # Subnet for private IP
  ip_address_type     = "Private"                  # Must use private IP for subnet

  container {
    name   = "${var.container_name_prefix}-${random_string.container_name_juiceshop.result}"
    image  = var.image
    cpu    = var.cpu_cores
    memory = var.memory_in_gb

    ports {
      port     = var.port
      protocol = "TCP"
    }
  }
}

# Application Gateway Configuration

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-public-ip"
  resource_group_name = azurerm_resource_group.rg_juiceshop.name
  location            = azurerm_resource_group.rg_juiceshop.location
  allocation_method   = "Static"
}

# Application Gateway
resource "azurerm_application_gateway" "appgw_juiceshop" {
  name                = "appgw-${random_pet.rg_name_juiceshop.id}"
  location            = azurerm_resource_group.rg_juiceshop.location
  resource_group_name = azurerm_resource_group.rg_juiceshop.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-gateway-ip"
    subnet_id = azurerm_subnet.subnet_juiceshop.id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-appgw"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  backend_address_pool {
    name = "appgw-backend-pool"
    backend_addresses {
      ip_address = azurerm_container_group.container_juiceshop.ip_address
    }
  }

  backend_http_settings {
    name                  = "appgw-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "frontend-ip-appgw"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "route-to-backend"
    priority                   = 10
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-http-settings"
  }
}

# Outputs
output "container_ipv4_address_juiceshop" {
  value = azurerm_container_group.container_juiceshop.ip_address
}

output "appgw_public_ip_juiceshop" {
  description = "Public IP Address of Application Gateway"
  value       = azurerm_application_gateway.appgw_juiceshop.frontend_ip_configuration[0].public_ip_address_id
}
