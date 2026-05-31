locals {
  app_config_all = {
    for row in csvdecode(file("${path.module}/csv/app_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  app_config = local.app_config_all["default"]

  tags = {
    Environment = local.app_config.environment
    Purpose     = local.app_config.purpose
    Owner       = local.app_config.owner
    CostCenter  = local.app_config.cost_center
    ExpiryDate  = local.app_config.expiry_date
  }

  resource_groups_all = {
    for row in csvdecode(file("${path.module}/csv/resource_groups.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  subnet_refs_all = {
    for row in csvdecode(file("${path.module}/csv/subnet_refs.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  vm_workloads = {
    for row in csvdecode(file("${path.module}/csv/vm_workloads.csv")) :
    row.key => row
    if lower(row.create) == "true" && lower(local.app_config.enable_vm) == "true"
  }

  aks_clusters = {
    for row in csvdecode(file("${path.module}/csv/aks_clusters.csv")) :
    row.key => row
    if lower(row.create) == "true" && lower(local.app_config.enable_aks) == "true"
  }

  ai_services = {
    for row in csvdecode(file("${path.module}/csv/ai_services.csv")) :
    row.key => row
    if lower(row.create) == "true" && lower(local.app_config.enable_ai_foundry) == "true"
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "workload" {
  for_each = local.resource_groups_all
  name     = each.value.name
}

data "azurerm_subnet" "workload" {
  for_each = local.subnet_refs_all

  name                 = each.value.name
  virtual_network_name = each.value.virtual_network_name
  resource_group_name  = data.azurerm_resource_group.workload[each.value.resource_group_key].name
}

resource "azurerm_network_interface" "vm" {
  for_each = local.vm_workloads

  name                = each.value.nic_name
  location            = data.azurerm_resource_group.workload["dev"].location
  resource_group_name = data.azurerm_resource_group.workload["dev"].name
  tags                = local.tags

  ip_configuration {
    name                          = each.value.ip_configuration_name
    subnet_id                     = data.azurerm_subnet.workload[each.value.subnet_key].id
    private_ip_address_allocation = each.value.private_ip_allocation
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = local.vm_workloads

  name                            = each.value.vm_name
  location                        = data.azurerm_resource_group.workload["dev"].location
  resource_group_name             = data.azurerm_resource_group.workload["dev"].name
  size                            = each.value.vm_size
  admin_username                  = local.app_config.vm_admin_username
  admin_password                  = local.app_config.vm_admin_password
  disable_password_authentication = lower(each.value.disable_password_authentication) == "true"
  network_interface_ids           = [azurerm_network_interface.vm[each.key].id]
  tags                            = local.tags

  os_disk {
    caching              = each.value.os_disk_caching
    storage_account_type = each.value.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = each.value.image_publisher
    offer     = each.value.image_offer
    sku       = each.value.image_sku
    version   = each.value.image_version
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  for_each = local.aks_clusters

  name                    = each.value.name
  location                = data.azurerm_resource_group.workload["dev"].location
  resource_group_name     = data.azurerm_resource_group.workload["dev"].name
  dns_prefix              = each.value.dns_prefix
  private_cluster_enabled = lower(each.value.private_cluster_enabled) == "true"
  private_dns_zone_id     = each.value.private_dns_zone_id
  sku_tier                = each.value.sku_tier
  tags                    = local.tags

  default_node_pool {
    name                        = each.value.node_pool_name
    vm_size                     = each.value.node_pool_vm_size
    node_count                  = tonumber(each.value.node_pool_count)
    vnet_subnet_id              = data.azurerm_subnet.workload[each.value.subnet_key].id
    temporary_name_for_rotation = each.value.node_pool_temporary_name
  }

  identity {
    type = each.value.identity_type
  }

  network_profile {
    network_plugin    = each.value.network_plugin
    load_balancer_sku = each.value.load_balancer_sku
    outbound_type     = each.value.outbound_type
  }
}

resource "random_string" "suffix" {
  length  = tonumber(local.app_config.random_suffix_length)
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_storage_account" "ai" {
  for_each = local.ai_services

  name                            = "${each.value.storage_name_prefix}${random_string.suffix.result}"
  location                        = data.azurerm_resource_group.workload["dev"].location
  resource_group_name             = data.azurerm_resource_group.workload["dev"].name
  account_tier                    = each.value.storage_tier
  account_replication_type        = each.value.storage_replication_type
  public_network_access_enabled   = lower(each.value.storage_public_network_access) == "true"
  allow_nested_items_to_be_public = lower(each.value.storage_allow_nested_items_public) == "true"
  tags                            = local.tags
}

resource "azurerm_key_vault" "ai" {
  for_each = local.ai_services

  name                          = "${each.value.key_vault_name_prefix}-${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.workload["dev"].location
  resource_group_name           = data.azurerm_resource_group.workload["dev"].name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = each.value.key_vault_sku
  public_network_access_enabled = lower(each.value.key_vault_public_network_access) == "true"
  purge_protection_enabled      = lower(each.value.key_vault_purge_protection) == "true"
  soft_delete_retention_days    = tonumber(each.value.key_vault_soft_delete_days)
  tags                          = local.tags
}

resource "azurerm_ai_foundry" "hub" {
  for_each = local.ai_services

  name                  = "${each.value.ai_foundry_name_prefix}-${random_string.suffix.result}"
  location              = data.azurerm_resource_group.workload["dev"].location
  resource_group_name   = data.azurerm_resource_group.workload["dev"].name
  storage_account_id    = azurerm_storage_account.ai[each.key].id
  key_vault_id          = azurerm_key_vault.ai[each.key].id
  public_network_access = each.value.ai_foundry_public_network_access
  tags                  = local.tags

  identity {
    type = each.value.identity_type
  }
}

resource "azurerm_private_endpoint" "ai_storage_blob" {
  for_each = local.ai_services

  name                = each.value.private_endpoint_name
  location            = data.azurerm_resource_group.workload["dev"].location
  resource_group_name = data.azurerm_resource_group.workload["dev"].name
  subnet_id           = data.azurerm_subnet.workload[each.value.private_endpoint_subnet_key].id
  tags                = local.tags

  private_service_connection {
    name                           = each.value.private_service_connection_name
    private_connection_resource_id = azurerm_storage_account.ai[each.key].id
    subresource_names              = [each.value.private_endpoint_subresource]
    is_manual_connection           = false
  }
}

resource "azurerm_cognitive_account" "openai" {
  for_each = local.ai_services

  name                          = "${each.value.cognitive_name_prefix}-${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.workload["dev"].location
  resource_group_name           = data.azurerm_resource_group.workload["dev"].name
  kind                          = each.value.cognitive_kind
  sku_name                      = each.value.cognitive_sku
  custom_subdomain_name         = "${each.value.cognitive_name_prefix}-${random_string.suffix.result}"
  public_network_access_enabled = lower(each.value.cognitive_public_network_access) == "true"
  tags                          = local.tags
}

resource "azurerm_cognitive_deployment" "chat" {
  for_each = lower(local.app_config.enable_openai_deployment) == "true" ? local.ai_services : {}

  name                 = local.app_config.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai[each.key].id

  model {
    format  = local.app_config.openai_model_format
    name    = local.app_config.openai_model_name
    version = local.app_config.openai_model_version
  }

  sku {
    name     = each.value.deployment_sku_name
    capacity = tonumber(each.value.deployment_capacity)
  }
}
