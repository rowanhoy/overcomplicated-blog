
data "azurerm_resource_group" "ocb_rg" {
  name = "rg-${var.app_name}-${var.environment}"
}

data "azurerm_user_assigned_identity" "umi" {
  name                = "id-${var.app_name}-${var.environment}"
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
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
  name                = "cae-${var.app_name}-${var.environment}"
  location            = data.azurerm_resource_group.ocb_rg.location
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    maximum_count         = 0
    minimum_count         = 0
  }
}

data "cloudflare_ip_ranges" "cloudflare" {}

resource "azurerm_container_app" "app" {
  name                         = "my-container-app"
  resource_group_name          = data.azurerm_resource_group.ocb_rg.name
  container_app_environment_id = azurerm_container_app_environment.capp_env.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    allow_insecure_connections = true

    dynamic "ip_security_restriction" {
      for_each = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
      content {
        name             = "cloudflare-${ip_security_restriction.value}"
        action           = "Allow"
        ip_address_range = ip_security_restriction.value
      }
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.umi.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.umi.id
  }

  template {
    max_replicas = 2
    min_replicas = 0
    http_scale_rule {
      name                = "http-scale-rule"
      concurrent_requests = 500
    }
    container {
      name   = "frontend-test"
      image  = "${azurerm_container_registry.acr.login_server}/next-fastapi"
      cpu    = "0.25"
      memory = "0.5Gi"

    }
  }
}

data "cloudflare_zone" "cf_zone" {
  name = "rowanhoy.com"
}

resource "cloudflare_record" "site" {
  zone_id = data.cloudflare_zone.cf_zone.id
  name    = var.environment == "prod" ? "s" : "${var.environment}-s"
  content = azurerm_container_app.app.ingress[0].fqdn
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
