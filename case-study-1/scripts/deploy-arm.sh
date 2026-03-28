#!/usr/bin/env bash
# ============================================================
# Case Study 1 — ARM Template Deployment Script
# SecureInsure: Multi-Region Infrastructure
#
# Usage:
#   ./deploy-arm.sh <environment> [location]
#
# Examples:
#   ./deploy-arm.sh dev
#   ./deploy-arm.sh staging eastus
#   ./deploy-arm.sh prod eastus
# ============================================================

set -euo pipefail

# ---- Configuration ----
ENVIRONMENT="${1:-dev}"
LOCATION="${2:-eastus}"
PREFIX="secureinsure"
RESOURCE_GROUP="rg-${PREFIX}-${ENVIRONMENT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/../arm/main.json"
PARAMS_FILE="${SCRIPT_DIR}/../arm/params.${ENVIRONMENT}.json"

# ---- Colour helpers ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step()   { echo -e "${BLUE}[STEP]${NC} $1"; }
print_ok()     { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()  { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- Validation ----
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  print_error "Environment must be dev, staging, or prod. Got: $ENVIRONMENT"
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  print_error "Template file not found: $TEMPLATE_FILE"
  exit 1
fi

if [[ ! -f "$PARAMS_FILE" ]]; then
  print_error "Parameters file not found: $PARAMS_FILE"
  exit 1
fi

# ---- Pre-flight check ----
print_step "Checking Azure CLI login status..."
if ! az account show &>/dev/null; then
  print_error "Not logged in. Run: az login"
  exit 1
fi

SUBSCRIPTION=$(az account show --query 'name' -o tsv)
print_ok "Logged in. Subscription: ${SUBSCRIPTION}"

# ---- Show what will be deployed ----
echo ""
echo "=============================================="
echo " Deployment Summary"
echo "=============================================="
echo "  Environment  : ${ENVIRONMENT}"
echo "  Location     : ${LOCATION}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Template     : ${TEMPLATE_FILE}"
echo "  Parameters   : ${PARAMS_FILE}"
echo "=============================================="
echo ""

read -p "Proceed with deployment? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# ---- Step 1: Create Resource Group ----
print_step "Creating resource group: ${RESOURCE_GROUP}..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags environment="${ENVIRONMENT}" project="${PREFIX}" \
  --output none
print_ok "Resource group created."

# ---- Step 2: Validate Template ----
print_step "Validating ARM template..."
az deployment group validate \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters @"${PARAMS_FILE}" \
  --output none
print_ok "Template validation passed."

# ---- Step 3: Deploy ----
DEPLOYMENT_NAME="deploy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
print_step "Deploying resources (deployment: ${DEPLOYMENT_NAME})..."

az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters @"${PARAMS_FILE}" \
  --output json | python3 -m json.tool 2>/dev/null || true

print_ok "Deployment completed."

# ---- Step 4: Show Deployed Resources ----
print_step "Deployed resources:"
az resource list \
  --resource-group "${RESOURCE_GROUP}" \
  --output table

# ---- Step 5: Show Outputs ----
print_step "Deployment outputs:"
az deployment group show \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query 'properties.outputs' \
  --output table 2>/dev/null || print_warn "Could not fetch outputs."

echo ""
print_ok "Deployment to ${ENVIRONMENT} completed successfully!"
echo ""
echo "To clean up resources:"
echo "  az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
