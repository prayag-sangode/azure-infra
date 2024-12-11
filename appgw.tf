# Application Gateway
resource "azurerm_application_gateway" "app_gateway" {
  name                = "myAppGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    name     = "Standard_v2"
    capacity = 2
  }

  frontend_ip_configuration {
    name                                     = "frontendConfig"
    public_ip_address_id                    = azurerm_public_ip.public_ip.id
  }

  backend_address_pool {
    name = "backendPool"

    backend_addresses {
      ip_address = var.aci_ip  # This will be the IP of your container group
    }
  }

  http_settings {
    name                               = "httpSettings"
    port                               = 80
    protocol                           = "Http"
    cookie_based_affinity              = "Disabled"
    request_timeout {
      seconds = 20
    }
  }

  listener {
    name                                 = "listener"
    frontend_ip_configuration_id       = azurerm_application_gateway_frontend_ip_configuration.frontend_config.id
    frontend_port {
      port = 80
    }
    protocol                             = "Http"
  }

  routing_rule {
    name                       = "rule1"
    priority                   = 100
    rule_type                  = "Basic"
    backend_address_pool_id    = azurerm_application_gateway_backend_address_pool.backend_pool.id
    http_settings_id           = azurerm_application_gateway_http_settings.http_settings.id
  }

  tags = {
    environment = "production"
  }
}

# Variables
variable "aci_ip" {
  type        = string
  description = "IP address of the backend container group"
}
