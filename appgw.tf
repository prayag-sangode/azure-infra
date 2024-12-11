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
    public_ip_address_id      = azurerm_public_ip.my_public_ip.id  # Define your public IP resource
  }

  backend_address_pool {
    name = "backend-pool"
    backend_addresses {
      ip_address = output.container_ipv4_address.value  # Reference the output here
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
        ip_address = output.container_ipv4_address.value  # Use the container IP here
      }
    }
  }
}
