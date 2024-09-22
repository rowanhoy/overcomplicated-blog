
data azurerm_resource_group "ocb_rg" {
  name     = "rg-overcomplicated-blog-${var.environment}"
}

resource "azurerm_user_assigned_identity" "umi" {
  location            = data.azurerm_resource_group.ocb_rg.location
  name                = "id-overcomplicated-blog-${var.environment}"
  resource_group_name = data.azurerm_resource_group.ocb_rg.name
}