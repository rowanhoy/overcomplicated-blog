
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

resource "azurerm_log_analytics_workspace" "ocb_log" {
  name                = "log-${var.app_name}-${var.environment}"
  location            = data.azurerm_resource_group.ocb_rg.location
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "capp_env" {
  name                       = "cae-${var.app_name}-${var.environment}"
  resource_group_name        = data.azurerm_resource_group.ocb_rg.name
  location                   = data.azurerm_resource_group.ocb_rg.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ocb_log.id
  workload_profile {
    name = "Consumption"
    workload_profile_type = "Consumption"
    maximum_count = 10
    minimum_count = 0
  }
}