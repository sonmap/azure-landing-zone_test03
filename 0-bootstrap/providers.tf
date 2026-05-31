provider "azurerm" {
  features {}
  subscription_id = local.bootstrap_config.platform_subscription_id
}
