locals {
  common_tags = merge({
    application = "nexus-one"
    environment = var.environment
    managed_by  = "terraform"
  }, var.tags)
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-nexus-one-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "platform" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.common_tags
}