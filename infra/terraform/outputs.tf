output "resource_group_name" {
  description = "Resource group created by the sandbox foundation."
  value       = azurerm_resource_group.platform.name
}

output "registry_login_server" {
  description = "Container registry endpoint; authenticate with federated identity or Azure CLI."
  value       = azurerm_container_registry.platform.login_server
}