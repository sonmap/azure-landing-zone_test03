#!/usr/bin/env bash
set -euo pipefail

python3 ../scripts/csv-to-tfvars.py csv/terraform_variables.csv terraform.tfvars
