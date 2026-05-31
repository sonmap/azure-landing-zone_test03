provider "azurerm" {
  features {}
  subscription_id = local.app_config.dev_subscription_id
}
