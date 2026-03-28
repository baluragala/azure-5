#!/usr/bin/env bash
# ============================================================
# Case Study 1 — Bicep Deployment Script
# SecureInsure: Multi-Region Infrastructure
#
# This script demonstrates:
#   1. Deploying the Bicep template directly
#   2. How to pass parameters inline (no params file needed)
#   3. Multi-region deployment with different address spaces
#
# Usage:
#   ./deploy-bicep.sh <environment> [location] [vnet-cidr]
#
# Examples:
#   ./deploy-bicep.sh dev
#   ./deploy-bicep.sh prod eastus 10.4.0.0/16
#   ./deploy-bicep.sh prod eastus2 10.2.0.0/16    ← DR region
# ============================================================

set -euo pipefail

ENVIRONMENT="${1:-dev}"
LOCATION="${2:-eastus}"
VNET_PREFIX="${3:-10.1.0.0/16}"

PREFIX="secureinsure"
RESOURCE_GROUP="rg-${PREFIX}-${ENVIRONMENT}-bicep"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_FILE="${SCRIPT_DIR}/../bicep/main.bicep"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }
print_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- Pre-flight ----
if ! az account show &>/dev/null; then
  print_error "Not logged in. Run: az login"
  exit 1
fi

# Derive subnet prefixes from VNet (simple calculation)
# VNet: 10.1.0.0/16 → Web: 10.1.1.0/24, App: 10.1.2.0/24
VNET_OCTETS=$(echo "$VNET_PREFIX" | cut -d'.' -f1,2)
WEB_SUBNET="${VNET_OCTETS}.1.0/24"
APP_SUBNET="${VNET_OCTETS}.2.0/24"

echo ""
echo "=============================================="
echo " Bicep Deployment"
echo "=============================================="
echo "  Environment  : ${ENVIRONMENT}"
echo "  Location     : ${LOCATION}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  VNet CIDR    : ${VNET_PREFIX}"
echo "  Web Subnet   : ${WEB_SUBNET}"
echo "  App Subnet   : ${APP_SUBNET}"
echo "=============================================="
echo ""

# ---- Create Resource Group ----
print_step "Creating resource group..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags environment="${ENVIRONMENT}" project="${PREFIX}" deployedBy="bicep" \
  --output none
print_ok "Resource group ready."

# ---- Deploy Bicep ----
DEPLOYMENT_NAME="bicep-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
print_step "Deploying Bicep template..."

az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${BICEP_FILE}" \
  --parameters \
      prefix="${PREFIX}" \
      environment="${ENVIRONMENT}" \
      location="${LOCATION}" \
      vnetAddressPrefix="${VNET_PREFIX}" \
      webSubnetPrefix="${WEB_SUBNET}" \
      appSubnetPrefix="${APP_SUBNET}" \
      vmSize="Standard_B1ms" \
      adminUsername="azureadmin" \
      adminPassword="P@ssw0rd2024!${ENVIRONMENT^}" \
  --output none

print_ok "Bicep deployment completed."

# ---- Show results ----
print_step "Resources deployed:"
az resource list --resource-group "${RESOURCE_GROUP}" --output table

print_step "Outputs:"
az deployment group show \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query 'properties.outputs' \
  --output jsonc 2>/dev/null || true

echo ""
print_ok "Done! Bicep deployment to ${ENVIRONMENT} successful."
echo ""

# ---- Show ARM vs Bicep comparison ----
echo "Line count comparison:"
ARM_LINES=$(wc -l < "${SCRIPT_DIR}/../arm/main.json")
BICEP_LINES=$(wc -l < "${BICEP_FILE}")
echo "  ARM template : ${ARM_LINES} lines"
echo "  Bicep        : ${BICEP_LINES} lines"
REDUCTION=$(( (ARM_LINES - BICEP_LINES) * 100 / ARM_LINES ))
echo "  Reduction    : ~${REDUCTION}% fewer lines with Bicep"
echo ""
echo "To clean up: az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
