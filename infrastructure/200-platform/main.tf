
data "azurerm_resource_group" "ocb_rg" {
  name = "rg-${var.app_name}-${var.environment}"
}

data "azurerm_user_assigned_identity" "umi" {
  name                = "id-${var.app_name}-${var.environment}"
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.app_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.ocb_rg.location
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
}

resource "azurerm_subnet" "container_subnet" {
  name                 = "snet-container"
  resource_group_name  = data.azurerm_resource_group.ocb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  

  delegation {
    name = "app-env"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
    
  }
}

resource "azurerm_subnet" "frontend_subnet" {
  name                 = "snet-frontend"
  resource_group_name  = data.azurerm_resource_group.ocb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_container_registry" "acr" {
  name                = "acr${var.app_name_simple}${var.environment}"
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
  location            = data.azurerm_resource_group.ocb_rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_role_assignment" "acr_role_assignment" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.umi.principal_id
}

resource "azurerm_container_app_environment" "capp_env" {
  name                       = "cae-${var.app_name}-${var.environment}"
  location                   = data.azurerm_resource_group.ocb_rg.location
  resource_group_name        = data.azurerm_resource_group.ocb_rg.name
  infrastructure_subnet_id = azurerm_subnet.container_subnet.id
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    maximum_count = 0
    minimum_count = 0
  }
  
}

resource "azurerm_container_app" "app" {
  name                         = "my-container-app"
  resource_group_name          = data.azurerm_resource_group.ocb_rg.name
  container_app_environment_id = azurerm_container_app_environment.capp_env.id
  revision_mode                = "Single"

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http2"
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
    allow_insecure_connections = true
    ip_security_restriction {
      action = "Allow"
      ip_address_range = azurerm_subnet.frontend_subnet.address_prefixes[0]
      name = "frontdoor"
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.umi.id]
  }

  registry {
    server = azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.umi.id
  }

  template {
    container {
      name  = "frontend-test"
      image = "nginxdemos/hello"
      cpu    = "0.25"
      memory = "0.5Gi"
    }
  }
}


data "azurerm_dns_zone" "rowanhoy_zone" {
  name                = "rowanhoy.com"
  resource_group_name = "rg-dns"
}

resource "azurerm_dns_cname_record" "site_cname" {
  name                = "site"
  zone_name           = data.azurerm_dns_zone.rowanhoy_zone.name
  resource_group_name = "rg-dns"
  ttl                 = 300
  record = "fd-overcomplicated-blog-dev.azurefd.net"
}

resource "azurerm_frontdoor" "fd" {
  depends_on = [ azurerm_dns_cname_record.site_cname]

  name                = "fd-${var.app_name}-${var.environment}"
  resource_group_name = data.azurerm_resource_group.ocb_rg.name

  # Frontend Endpoint
  frontend_endpoint {
    name      = "site-rowanhoy-com"
    host_name = "site.rowanhoy.com"
  }

  # Backend Pool for the container app
  backend_pool {
    name = "ocb-backend-pool"

    backend {
      host_header = azurerm_container_app.app.latest_revision_fqdn
      address     = azurerm_container_app.app.latest_revision_fqdn
      http_port   = 80
      https_port  = 443
    }

    load_balancing_name = "lb-pool-1"
    health_probe_name   = "http-health-probe"
  }

  # Backend Pool Health Probe
  backend_pool_health_probe {
    name     = "http-health-probe"
    path     = "/"
    protocol = "Http"
  }

  # Backend Pool Load Balancing
  backend_pool_load_balancing {
    name                          = "lb-pool-1"
    sample_size                   = 4
    successful_samples_required    = 2
    additional_latency_milliseconds = 0
  }

  # Routing Rule
  routing_rule {
    name               = "ocb-routing-rule"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["site-rowanhoy-com"]

    forwarding_configuration {
      backend_pool_name     = "ocb-backend-pool"
      forwarding_protocol   = "MatchRequest"
    }
  }
}
