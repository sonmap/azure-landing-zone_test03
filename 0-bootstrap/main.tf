locals {
  bootstrap_config_all = {
    for row in csvdecode(file("${path.module}/csv/bootstrap_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  bootstrap_config = local.bootstrap_config_all["default"]

  bootstrap_all = {
    for row in csvdecode(file("${path.module}/csv/bootstrap.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  tags = {
    Environment = local.bootstrap_config.environment
    Purpose     = local.bootstrap_config.purpose
    Owner       = local.bootstrap_config.owner
    CostCenter  = local.bootstrap_config.cost_center
    ExpiryDate  = local.bootstrap_config.expiry_date
  }
}

resource "random_string" "suffix" {
  length  = tonumber(local.bootstrap_config.random_suffix_length)
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate" {
  for_each = local.bootstrap_all

  name     = each.value.resource_group_name
  location = each.value.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  for_each = local.bootstrap_all

  name                            = "${each.value.storage_account_prefix}${random_string.suffix.result}"
  location                        = azurerm_resource_group.tfstate[each.key].location
  resource_group_name             = azurerm_resource_group.tfstate[each.key].name
  account_tier                    = each.value.account_tier
  account_replication_type        = each.value.account_replication_type
  min_tls_version                 = each.value.min_tls_version
  allow_nested_items_to_be_public = lower(each.value.allow_nested_items_to_be_public) == "true"
  shared_access_key_enabled       = lower(each.value.shared_access_key_enabled) == "true"
  tags                            = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  for_each = local.bootstrap_all

  name                  = each.value.container_name
  storage_account_id    = azurerm_storage_account.tfstate[each.key].id
  container_access_type = local.bootstrap_config.storage_container_access_type
}
