output "dev_policy_assignment_ids" {
  value = { for key, assignment in azurerm_subscription_policy_assignment.dev : key => assignment.id }
}

output "budget_ids" {
  value = merge(
    { for key, budget in azurerm_consumption_budget_subscription.platform : key => budget.id },
    { for key, budget in azurerm_consumption_budget_subscription.dev : key => budget.id }
  )
}
