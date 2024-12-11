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
  subnet_ids          = [azurerm_subnet.subnet.id]
  ip_address_type     = "Private"

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

# Public IP Resource
resource "azurerm_public_ip" "my_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                  = "Standard"
}

# Application Gateway Backend Address Pool
resource "azurerm_application_gateway_backend_address_pool" "backend_pool" {
  name                      = "backend-pool"
  resource_group_name       = azurerm_resource_group.rg.name
  application_gateway_name  = azurerm_application_gateway.app_gateway.name

  backend_addresses {
    ip_address = output.container_ipv4_address.value  # Reference the container's IP here
  }
}

# Application Gateway HTTP Settings
resource "azurerm_application_gateway_http_settings" "http_settings" {
  name                           = "http-settings"
  resource_group_name            = azurerm_resource_group.rg.name
  application_gateway_name       = azurerm_application_gateway.app_gateway.name
  port                           = 80
  protocol                       = "Http"
  cookie_based_affinity          = "Disabled"

  request_timeout {
    seconds = 20
  }
}

# Application Gateway Resource
resource "azurerm_application_gateway" "app_gateway" {
  name                = "myAppGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  frontend_ip_configuration {
    name                      = "frontend-config"
    public_ip_address_id      = azurerm_public_ip.my_public_ip.id
  }

  backend_address_pool {
    name = "backend-pool"
    backend_addresses {
      ip_address = output.container_ipv4_address.value  # Reference the container's IP here
    }
  }

  http_settings {
    name                           = "http-settings"
    port                           = 80
    protocol                       = "Http"
    cookie_based_affinity          = "Disabled"
    request_timeout {
      seconds = 20
    }
  }

  listener {
    name                                 = "app-gateway-listener"
    frontend_ip_configuration_id        = azurerm_application_gateway_frontend_ip_configuration.my_frontend_ip.id
    frontend_port_id                    = azurerm_application_gateway_frontend_port.my_frontend_port.id
    protocol                             = "Http"
    ssl_certificate_id                  = null
  }

  gateway_ip_configuration {
    name                 = "app-gateway-vnet"
    subnet_id            = azurerm_subnet.subnet.id
  }

  url_path_map {
    default_backend_address_pool_id = azurerm_application_gateway_backend_address_pool.backend_pool.id
    default_backend_http_settings_id = azurerm_application_gateway_http_settings.http_settings.id
    default_backend_address_pool {
      backend_addresses {
        ip_address = output.container_ipv4_address.value
      }
    }
  }
}
