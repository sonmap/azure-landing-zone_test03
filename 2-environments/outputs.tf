output "hub_resource_group_name" {
  value = azurerm_resource_group.platform["hub"].name
}

output "dev_resource_group_name" {
  value = azurerm_resource_group.dev["dev"].name
}

output "department_environment_resource_group_names" {
  value = { for key, rg in azurerm_resource_group.department_dev : key => rg.name }
}
