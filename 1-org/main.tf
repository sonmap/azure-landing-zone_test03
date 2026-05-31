locals {
  org_config_all = {
    for row in csvdecode(file("${path.module}/csv/org_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  org_config = local.org_config_all["default"]

  budget_month_start = "${substr(local.org_config.expiry_date, 0, 8)}01T00:00:00Z"

  policy_definitions_all = {
    for row in csvdecode(file("${path.module}/csv/policy_definitions.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  policy_rule_types_all = {
    for row in csvdecode(file("${path.module}/csv/policy_rule_types.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  policy_assignments_all = {
    for row in csvdecode(file("${path.module}/csv/policy_assignments.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  budgets_all = {
    for row in csvdecode(file("${path.module}/csv/budgets.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  budget_notifications_all = {
    for row in csvdecode(file("${path.module}/csv/budget_notifications.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  dev_policy_definitions = {
    for key, row in local.policy_definitions_all : key => row
    if row.subscription_key == "dev"
  }

  dev_policy_assignments = {
    for key, row in local.policy_assignments_all : key => row
    if row.subscription_key == "dev"
  }

  platform_budgets = {
    for key, row in local.budgets_all : key => row
    if row.subscription_key == "platform"
  }

  dev_budgets = {
    for key, row in local.budgets_all : key => row
    if row.subscription_key == "dev"
  }

  policy_rules_json = {
    for key, definition in local.policy_definitions_all : key => jsonencode({
      if = {
        anyOf = [
          for rule_key, rule in local.policy_rule_types_all : {
            field  = "type"
            equals = rule.equals
          }
          if rule.policy_key == key
        ]
      }
      then = {
        effect = definition.effect
      }
    })
  }

  budget_notifications_by_budget = {
    for budget_key in keys(local.budgets_all) : budget_key => [
      for notification_key, notification in local.budget_notifications_all : notification
      if notification.budget_key == budget_key
    ]
  }
}

resource "azurerm_policy_definition" "dev" {
  provider = azurerm.dev
  for_each = local.dev_policy_definitions

  name         = each.value.name
  policy_type  = each.value.policy_type
  mode         = each.value.mode
  display_name = each.value.display_name
  policy_rule  = local.policy_rules_json[each.key]
}

resource "azurerm_subscription_policy_assignment" "dev" {
  provider = azurerm.dev
  for_each = local.dev_policy_assignments

  name                 = each.value.name
  subscription_id      = "/subscriptions/${local.org_config.dev_subscription_id}"
  policy_definition_id = azurerm_policy_definition.dev[each.value.policy_key].id
  display_name         = each.value.display_name
}

resource "azurerm_consumption_budget_subscription" "platform" {
  provider = azurerm.platform
  for_each = local.platform_budgets

  name            = each.value.name
  subscription_id = "/subscriptions/${local.org_config.platform_subscription_id}"
  amount          = tonumber(each.value.amount)
  time_grain      = each.value.time_grain

  time_period {
    start_date = each.value.start_date_mode == "expiry_month_start" ? local.budget_month_start : each.value.start_date_mode
  }

  dynamic "notification" {
    for_each = local.budget_notifications_by_budget[each.key]
    content {
      enabled        = lower(notification.value.enabled) == "true"
      threshold      = tonumber(notification.value.threshold)
      operator       = notification.value.operator
      threshold_type = notification.value.threshold_type
      contact_emails = notification.value.contact_emails_source == "config.budget_contact_emails" ? split(";", local.org_config.budget_contact_emails) : split(";", notification.value.contact_emails_source)
    }
  }
}

resource "azurerm_consumption_budget_subscription" "dev" {
  provider = azurerm.dev
  for_each = local.dev_budgets

  name            = each.value.name
  subscription_id = "/subscriptions/${local.org_config.dev_subscription_id}"
  amount          = tonumber(each.value.amount)
  time_grain      = each.value.time_grain

  time_period {
    start_date = each.value.start_date_mode == "expiry_month_start" ? local.budget_month_start : each.value.start_date_mode
  }

  dynamic "notification" {
    for_each = local.budget_notifications_by_budget[each.key]
    content {
      enabled        = lower(notification.value.enabled) == "true"
      threshold      = tonumber(notification.value.threshold)
      operator       = notification.value.operator
      threshold_type = notification.value.threshold_type
      contact_emails = notification.value.contact_emails_source == "config.budget_contact_emails" ? split(";", local.org_config.budget_contact_emails) : split(";", notification.value.contact_emails_source)
    }
  }
}
