# GCP to Azure Landing Zone Mapping

Source repository used for this conversion:

```text
/home/son/terraform-gcp-landigzon
```

Target repository:

```text
/home/son/azure_land03
```

## Layer Mapping

| GCP source layer | Source purpose | Azure target layer | Azure implementation |
|---|---|---|---|
| `0-bootstrap` | Seed project, Terraform state bucket, deployer service accounts, CI/CD bootstrap | `0-bootstrap` | Resource group, storage account, blob container for Terraform state |
| `1-org` | Common organization controls, logging/security/billing projects, org policies, central IAM | `1-org` | Subscription-level Azure Policy definitions/assignments, budgets, Entra ID SSO/IAM model |
| `2-environments` | Development, nonproduction, production folders and shared projects | `2-environments` | Platform baseline and department-separated `dev`, `qa`, `prd` environment inventory |
| `3-networks-hub-and-spoke` | Hub and spoke Shared VPC, DNS hub, private access, firewall baseline, optional NAT/VPN/Interconnect | `3-networks-hub-and-spoke` | Platform hub VNet, Dev spoke VNets, subnets, NSG, Linux NVA, route table, private DNS zones, peering |
| `4-projects` | Service projects attached to Shared VPC and infra pipeline boundaries | `4-projects` | Workload project catalog mapped to Azure resource group/subnet boundaries |
| `5-app-infra` | Example application infrastructure in business unit projects | `5-app-infra` | Private Linux VM, private AKS, Azure AI Foundry dependencies, Azure OpenAI account/deployment option |

## Design Decisions

This conversion keeps the GCP repository's staged operating model instead of flattening everything into one Terraform root. Each layer can be initialized, planned, and applied independently.

The GCP foundation separates many concerns into projects and folders. The Azure lab keeps the same concerns but maps them to subscriptions, resource groups, VNets, subnets, policies, and tags. For a production Enterprise-Scale Landing Zone, management groups, Azure Firewall, Bastion, centralized logging, Defender for Cloud, and private DNS resolver would normally be added.

The GCP network source includes Shared VPC, DNS hub, firewall baselines, private service access, and optional NAT/VPN/Interconnect. The Azure target implements a lower-cost hub-and-spoke pattern: hub VNet, spoke VNets, VNet peering, private DNS zones, an NSG, a small Linux NVA, and a route table for controlled egress.

The GCP app layer deploys a sample workload through the project pipeline. The Azure target deploys three workload types directly from CSV inventory: VM, AKS, and AI.

## CSV Inventory

Azure target values are controlled by CSV files in each layer:

| Layer | CSV files |
|---|---|
| `0-bootstrap` | `csv/bootstrap.csv` |
| `1-org` | `csv/policy_definitions.csv`, `csv/policy_rule_types.csv`, `csv/policy_assignments.csv`, `csv/budgets.csv`, `csv/budget_notifications.csv`, `csv/iam_groups.csv`, `csv/rbac_model.csv` |
| `2-environments` | `csv/resource_groups.csv`, `csv/department_environments.csv` |
| `3-networks-hub-and-spoke` | `csv/resource_groups.csv`, `csv/networks.csv`, `csv/subnets.csv`, `csv/routes.csv`, `csv/hub_entry.csv`, `csv/nsg_rules.csv`, `csv/private_dns_zones.csv` |
| `4-projects` | `csv/workload_projects.csv` |
| `5-app-infra` | `csv/resource_groups.csv`, `csv/subnet_refs.csv`, `csv/vm_workloads.csv`, `csv/aks_clusters.csv`, `csv/ai_services.csv` |

## Apply Order

```bash
cd /home/son/azure_land03

terraform -chdir=0-bootstrap init
terraform -chdir=0-bootstrap plan

terraform -chdir=1-org init
terraform -chdir=1-org plan

terraform -chdir=2-environments init
terraform -chdir=2-environments plan

terraform -chdir=3-networks-hub-and-spoke init
terraform -chdir=3-networks-hub-and-spoke plan

terraform -chdir=4-projects init
terraform -chdir=4-projects plan

terraform -chdir=5-app-infra init
terraform -chdir=5-app-infra plan
```

## Validation

```bash
cd /home/son/azure_land03
for d in 0-bootstrap 1-org 2-environments 3-networks-hub-and-spoke 4-projects 5-app-infra; do
  terraform -chdir="$d" fmt -check -recursive
  terraform -chdir="$d" validate
done
```
