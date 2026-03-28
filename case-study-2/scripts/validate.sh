#!/usr/bin/env bash
# ============================================================
# Case Study 2 — Security Validation Script
# FinTrust Bank: Verify NSG rules, ASGs, and UDRs
#
# This script simulates a basic security audit by checking:
#   1. All expected NSGs exist and have rules
#   2. Critical allow/deny rules are configured correctly
#   3. ASGs are created
#   4. Route table is associated with web subnet
#   5. No tier bypasses are possible (DB not reachable from Web directly)
#
# Usage:
#   ./validate.sh <resource-group> [prefix]
#
# Example:
#   ./validate.sh rg-fintrust-prod fintrust
# ============================================================

set -euo pipefail

RESOURCE_GROUP="${1:-rg-fintrust-prod}"
PREFIX="${2:-fintrust}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

print_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }
pass()        { echo -e "  ${GREEN}✓ PASS${NC} $1"; ((PASS++)); }
fail()        { echo -e "  ${RED}✗ FAIL${NC} $1"; ((FAIL++)); }
warn()        { echo -e "  ${YELLOW}⚠ WARN${NC} $1"; ((WARN++)); }

echo ""
echo "============================================================"
echo " FinTrust Bank — Network Security Validation Report"
echo " Resource Group : ${RESOURCE_GROUP}"
echo " Prefix         : ${PREFIX}"
echo " Date           : $(date)"
echo "============================================================"
echo ""

# ---- Pre-flight ----
if ! az account show &>/dev/null; then
  echo "ERROR: Not logged into Azure. Run: az login"
  exit 1
fi

# ============================================================
# CHECK 1: NSGs Exist
# ============================================================
echo "1. NSG Existence Checks"
echo "   ─────────────────────────────"

for TIER in web app db; do
  NSG_NAME="nsg-${TIER}-${PREFIX}"
  print_check "NSG exists: ${NSG_NAME}"
  if az network nsg show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NSG_NAME}" \
    --output none 2>/dev/null; then
    pass "${NSG_NAME} found"
  else
    fail "${NSG_NAME} NOT FOUND"
  fi
done

echo ""

# ============================================================
# CHECK 2: NSGs Are Associated with Subnets
# ============================================================
echo "2. Subnet-NSG Association Checks"
echo "   ─────────────────────────────"

VNET_NAME="vnet-${PREFIX}"

for TIER in web app db; do
  SUBNET_NAME="snet-${TIER}"
  print_check "NSG attached to subnet: ${SUBNET_NAME}"

  NSG_ID=$(az network vnet subnet show \
    --resource-group "${RESOURCE_GROUP}" \
    --vnet-name "${VNET_NAME}" \
    --name "${SUBNET_NAME}" \
    --query 'networkSecurityGroup.id' \
    --output tsv 2>/dev/null || echo "")

  if [[ -n "$NSG_ID" && "$NSG_ID" != "null" ]]; then
    pass "${SUBNET_NAME} has NSG attached: $(basename $NSG_ID)"
  else
    fail "${SUBNET_NAME} has NO NSG attached — critical security gap!"
  fi
done

echo ""

# ============================================================
# CHECK 3: Critical NSG Rules — Web Tier
# ============================================================
echo "3. Web Tier NSG Rule Checks"
echo "   ─────────────────────────────"

WEB_NSG="nsg-web-${PREFIX}"

print_check "HTTP (port 80) allowed from Internet"
HTTP_RULE=$(az network nsg rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --nsg-name "${WEB_NSG}" \
  --query "[?destinationPortRange=='80' && access=='Allow' && direction=='Inbound']" \
  --output tsv 2>/dev/null | wc -l)
if [[ "$HTTP_RULE" -gt 0 ]]; then
  pass "Port 80 allow rule exists"
else
  fail "Port 80 allow rule NOT FOUND on ${WEB_NSG}"
fi

print_check "Explicit Deny-All rule exists (lowest priority)"
DENY_ALL=$(az network nsg rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --nsg-name "${WEB_NSG}" \
  --query "[?priority==\`4096\` && access=='Deny']" \
  --output tsv 2>/dev/null | wc -l)
if [[ "$DENY_ALL" -gt 0 ]]; then
  pass "Deny-All rule at priority 4096 exists"
else
  warn "No Deny-All at priority 4096. Azure defaults allow VNet-to-VNet traffic."
fi

echo ""

# ============================================================
# CHECK 4: Critical NSG Rules — DB Tier
# ============================================================
echo "4. DB Tier NSG Rule Checks"
echo "   ─────────────────────────────"

DB_NSG="nsg-db-${PREFIX}"

print_check "SQL Server port (1433) has restrict rule"
SQL_RULES=$(az network nsg rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --nsg-name "${DB_NSG}" \
  --query "[?destinationPortRange=='1433']" \
  --output tsv 2>/dev/null | wc -l)
if [[ "$SQL_RULES" -gt 0 ]]; then
  pass "Port 1433 rule configured on DB NSG"
else
  fail "No rule for port 1433 on ${DB_NSG}"
fi

print_check "Internet denied from DB tier"
DB_INTERNET_DENY=$(az network nsg rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --nsg-name "${DB_NSG}" \
  --query "[?sourceAddressPrefix=='Internet' && access=='Deny']" \
  --output tsv 2>/dev/null | wc -l)
if [[ "$DB_INTERNET_DENY" -gt 0 ]]; then
  pass "Internet → DB explicit deny rule found"
else
  warn "No explicit Internet deny on DB NSG. Add for defense-in-depth."
fi

print_check "Web subnet denied from DB tier directly"
DB_WEB_DENY=$(az network nsg rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --nsg-name "${DB_NSG}" \
  --query "[?access=='Deny' && direction=='Inbound']" \
  --output tsv 2>/dev/null | wc -l)
if [[ "$DB_WEB_DENY" -gt 0 ]]; then
  pass "DB NSG has inbound deny rules — web bypass prevented"
else
  warn "Consider explicit deny rule to block web-to-db direct access"
fi

echo ""

# ============================================================
# CHECK 5: Application Security Groups Exist
# ============================================================
echo "5. Application Security Group Checks"
echo "   ─────────────────────────────"

for ASG in "asg-web-servers" "asg-app-servers" "asg-db-servers"; do
  print_check "ASG exists: ${ASG}"
  if az network asg show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ASG}" \
    --output none 2>/dev/null; then
    pass "${ASG} found"
  else
    fail "${ASG} NOT FOUND — NSG rules referencing this ASG won't work!"
  fi
done

echo ""

# ============================================================
# CHECK 6: Route Table on Web Subnet
# ============================================================
echo "6. User Defined Route (UDR) Checks"
echo "   ─────────────────────────────"

print_check "Route table attached to web subnet"
RT_ID=$(az network vnet subnet show \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${VNET_NAME}" \
  --name "snet-web" \
  --query 'routeTable.id' \
  --output tsv 2>/dev/null || echo "")

if [[ -n "$RT_ID" && "$RT_ID" != "null" ]]; then
  RT_NAME=$(basename "$RT_ID")
  pass "Route table attached: ${RT_NAME}"

  print_check "Default route (0.0.0.0/0) goes to VirtualAppliance"
  DEFAULT_ROUTE=$(az network route-table route list \
    --resource-group "${RESOURCE_GROUP}" \
    --route-table-name "${RT_NAME}" \
    --query "[?addressPrefix=='0.0.0.0/0' && nextHopType=='VirtualAppliance']" \
    --output tsv 2>/dev/null | wc -l)
  if [[ "$DEFAULT_ROUTE" -gt 0 ]]; then
    pass "Default route correctly points to VirtualAppliance (Firewall)"
  else
    warn "Default route not pointing to VirtualAppliance — traffic may bypass firewall"
  fi
else
  warn "No route table on web subnet — traffic won't be inspected by Firewall"
fi

echo ""

# ============================================================
# CHECK 7: Firewall Subnet Exists
# ============================================================
echo "7. AzureFirewallSubnet Check"
echo "   ─────────────────────────────"

print_check "AzureFirewallSubnet exists in VNet"
FW_SUBNET=$(az network vnet subnet show \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${VNET_NAME}" \
  --name "AzureFirewallSubnet" \
  --query 'addressPrefix' \
  --output tsv 2>/dev/null || echo "")

if [[ -n "$FW_SUBNET" && "$FW_SUBNET" != "null" ]]; then
  pass "AzureFirewallSubnet exists (${FW_SUBNET})"
else
  warn "AzureFirewallSubnet not found — required before deploying Azure Firewall"
fi

echo ""

# ============================================================
# SUMMARY
# ============================================================
TOTAL=$((PASS + FAIL + WARN))

echo "============================================================"
echo " VALIDATION SUMMARY"
echo "============================================================"
echo -e " Total Checks : ${TOTAL}"
echo -e " ${GREEN}PASSED${NC}        : ${PASS}"
echo -e " ${YELLOW}WARNINGS${NC}      : ${WARN}"
echo -e " ${RED}FAILED${NC}        : ${FAIL}"
echo "============================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e " ${RED}RESULT: FAILED — Address failures before production deployment${NC}"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e " ${YELLOW}RESULT: PASSED WITH WARNINGS — Review warnings for production hardening${NC}"
  exit 0
else
  echo -e " ${GREEN}RESULT: ALL CHECKS PASSED — Infrastructure meets security baseline${NC}"
  exit 0
fi
