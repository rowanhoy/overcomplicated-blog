terraform {
  backend "azurerm" {
    use_azuread_auth     = true
    container_name       = "tfstate"
    key                  = "301-webapp.terraform.tfstate"
    subscription_id      = "615fafa0-b83c-4cf8-bc91-6e9ff4f3edca"
    tenant_id            = "965e53df-ba71-4376-beca-966fd0ee88d8"
  }
}
