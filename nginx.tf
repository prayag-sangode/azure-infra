resource "azurerm_container_group" "nginx_proxy" {
  name                = "nginx-proxy-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  restart_policy      = "Always"
  subnet_ids          = [azurerm_subnet.subnet.id]
  ip_address_type     = "Private"

  container {
    name   = "nginx-proxy"
    image  = "nginx:latest"
    cpu    = 1
    memory = 2

    ports {
      port     = 443
      protocol = "TCP"
    }

    volume_mount {
      name      = "nginx-config"
      mount_path = "/etc/nginx/conf.d"
    }
  }

  volume {
    name = "nginx-config"

    content {
      path     = "default.conf"
      content  = <<EOT
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    location / {
        proxy_pass http://${azurerm_container_group.container.ip_address}:${var.port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOT
    }
  }
}
