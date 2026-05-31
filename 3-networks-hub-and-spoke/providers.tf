provider "azurerm" {
  alias = "platform"
  features {}
  subscription_id = local.network_config.platform_subscription_id
}

provider "azurerm" {
  alias = "dev"
  features {}
  subscription_id = local.network_config.dev_subscription_id
}
