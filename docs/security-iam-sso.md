# Security, IAM, SSO, and Environment Separation

## Requirements

| Requirement | Azure implementation |
|---|---|
| Every system must use SSO | Microsoft Entra ID is the central identity provider. Workload portals, AKS access, Azure AI services, GitHub/Azure DevOps, and management access must use Entra ID SSO. |
| Department environments must be separated | Each department has `dev`, `qa`, and `prd` boundaries using resource groups, network spokes, tags, budgets, policies, and RBAC groups. |
| IAM must be integrated | Users are assigned to Entra ID groups. Azure RBAC is assigned to groups. Direct user-level RBAC assignment is not allowed except break-glass. |
| Production must be more restricted than non-production | `prd` uses separate approver groups, stricter RBAC, stricter policy assignments, stronger network controls, and optional separate subscription placement. |

## Identity Model

| Identity area | Standard |
|---|---|
| Workforce identity | Microsoft Entra ID users or federated enterprise identity |
| Application identity | Managed identities for Azure resources |
| Human access | Entra ID groups mapped to Azure RBAC |
| Emergency access | Break-glass account with MFA/exclusion process documented separately |
| Service credentials | No static secrets in Terraform or CSV. Use Key Vault and managed identity. |

## Department and Environment Model

| Department | Environment | Boundary |
|---|---|---|
| Shared platform | `platform` | Hub network, policy, central IAM, state, shared DNS |
| Finance | `dev` | Finance dev resource group and spoke |
| Finance | `qa` | Finance QA resource group and spoke |
| Finance | `prd` | Finance production resource group/spoke or production subscription |
| HR | `dev` | HR dev resource group and spoke |
| HR | `qa` | HR QA resource group and spoke |
| HR | `prd` | HR production resource group/spoke or production subscription |

Add or remove departments in `2-environments/csv/department_environments.csv`.

## RBAC Group Pattern

Use this naming pattern:

```text
grp-<prefix>-<department>-<environment>-<role>
```

| Group | Purpose |
|---|---|
| `grp-land03-platform-admin` | Landing zone platform administrators |
| `grp-land03-finance-dev-contributor` | Finance dev contributors |
| `grp-land03-finance-qa-reader` | Finance QA readers |
| `grp-land03-finance-prd-approver` | Finance production approvers |
| `grp-land03-hr-prd-reader` | HR production readers |

## Minimum Role Design

| Role group | Azure RBAC role | Scope |
|---|---|---|
| Platform admin | Owner or User Access Administrator plus Contributor | Platform subscription or management group |
| Department dev contributor | Contributor | Department `dev` resource group |
| Department QA contributor | Contributor | Department `qa` resource group |
| Department production operator | Contributor or custom limited role | Department `prd` resource group |
| Department production reader | Reader | Department `prd` resource group |
| Security auditor | Security Reader / Reader | Management group, subscriptions, or all environment resource groups |

## SSO Integration Targets

| System | SSO requirement |
|---|---|
| Azure Portal | Entra ID MFA and Conditional Access |
| AKS | Entra ID integrated Kubernetes RBAC |
| Azure AI Foundry | Entra ID user/group access |
| Azure OpenAI | Azure RBAC and managed identities |
| Linux VMs | Entra ID login extension or SSH through controlled admin path |
| CI/CD | Federated identity or managed identity, no long-lived secrets |
| Terraform | Workload identity federation or service principal with scoped RBAC |

## Terraform Implementation Notes

The current repository records IAM and environment intent as CSV inventory first. To make IAM fully managed by Terraform, add the `azuread` provider to `1-org` and create:

| Resource | Purpose |
|---|---|
| `azuread_group` | Central Entra ID groups |
| `azurerm_role_assignment` | RBAC assignments from groups to resource groups/subscriptions |
| `azurerm_policy_assignment` | Environment-specific controls |
| `azurerm_management_group` | Optional production-grade hierarchy |

Before enabling Terraform-managed Entra ID groups, confirm the deployment identity has Microsoft Graph permissions to create groups and read directory objects.
