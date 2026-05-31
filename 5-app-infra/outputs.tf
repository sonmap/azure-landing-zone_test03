output "spoke01_vm_private_ip" {
  value = { for key, nic in azurerm_network_interface.vm : key => nic.private_ip_address }
}

output "aks_private_fqdn" {
  value = { for key, aks in azurerm_kubernetes_cluster.aks : key => aks.private_fqdn }
}

output "ai_foundry_id" {
  value = { for key, hub in azurerm_ai_foundry.hub : key => hub.id }
}

output "openai_endpoint" {
  value = { for key, account in azurerm_cognitive_account.openai : key => account.endpoint }
}
