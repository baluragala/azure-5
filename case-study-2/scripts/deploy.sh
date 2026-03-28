#!/usr/bin/env bash
# ============================================================
# Case Study 2 — 3-Tier Network Security Deployment Script
# FinTrust Bank: NSGs, ASGs, UDRs
#
# Usage:
#   ./deploy.sh [resource-group] [prefix] [location]
#
# Examples:
#   ./deploy.sh
#   ./deploy.sh rg-fintrust-prod fintrust eastus
# ============================================================

set -euo pipefail

RESOURCE_GROUP="${1:-rg-fintrust-prod}"
PREFIX="${2:-fintrust}"
LOCATION="${3:-eastus}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/../arm/network-security.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }
print_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- Pre-flight ----
if ! az account show &>/dev/null; then
  print_error "Not logged in. Run: az login"
  exit 1
fi

echo ""
echo "=============================================="
echo " FinTrust Bank — 3-Tier Security Deployment"
echo "=============================================="
echo "  Resource Group : ${RESOURCE_GROUP}"
echo "  Prefix         : ${PREFIX}"
echo "  Location       : ${LOCATION}"
echo ""
echo " Resources to be created:"
echo "   ✓ 1 Virtual Network (10.0.0.0/16)"
echo "   ✓ 4 Subnets (web, app, db, firewall)"
echo "   ✓ 3 NSGs (web, app, db)"
echo "   ✓ 3 ASGs (asg-web-servers, asg-app-servers, asg-db-servers)"
echo "   ✓ 1 Route Table (web tier UDR)"
echo "=============================================="
echo ""

read -p "Deploy? (y/N): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo "Cancelled." && exit 0

# ---- Step 1: Create Resource Group ----
print_step "Creating resource group: ${RESOURCE_GROUP}..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags environment=prod project="${PREFIX}" compliance=pci-dss architecture=3-tier \
  --output none
print_ok "Resource group ready."

# ---- Step 2: Validate Template ----
print_step "Validating ARM template..."
az deployment group validate \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters prefix="${PREFIX}" location="${LOCATION}" \
  --output none
print_ok "Template is valid."

# ---- Step 3: Deploy ----
DEPLOYMENT_NAME="fintrust-$(date +%Y%m%d-%H%M%S)"
print_step "Deploying 3-tier security infrastructure (${DEPLOYMENT_NAME})..."

az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters prefix="${PREFIX}" location="${LOCATION}" \
  --output none

print_ok "Deployment complete!"

# ---- Step 4: Print Resources ----
echo ""
print_step "Resources deployed:"
az resource list \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[].{Name:name, Type:type}" \
  --output table

# ---- Step 5: Print NSG Summary ----
echo ""
print_step "NSG rule counts:"
for NSG in "nsg-web-${PREFIX}" "nsg-app-${PREFIX}" "nsg-db-${PREFIX}"; do
  COUNT=$(az network nsg rule list \
    --resource-group "${RESOURCE_GROUP}" \
    --nsg-name "${NSG}" \
    --query 'length(@)' \
    --output tsv 2>/dev/null || echo "N/A")
  echo "  ${NSG}: ${COUNT} rules"
done

# ---- Step 6: Print ASG Summary ----
echo ""
print_step "Application Security Groups:"
az network asg list \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[].{Name:name, Location:location}" \
  --output table

# ---- Step 7: Route Table ----
echo ""
print_step "Route table for web tier:"
az network route-table route list \
  --resource-group "${RESOURCE_GROUP}" \
  --route-table-name "rt-web-${PREFIX}" \
  --output table 2>/dev/null || print_warn "Route table not found (check template)"

echo ""
print_ok "FinTrust Bank 3-tier security deployment successful!"
echo ""
echo "Next steps:"
echo "  1. Run validate.sh to verify security rules"
echo "  2. Deploy VMs into the subnets and assign ASGs"
echo "  3. Deploy Azure Firewall into AzureFirewallSubnet"
echo ""
echo "Cleanup: az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
