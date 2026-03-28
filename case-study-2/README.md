# Case Study 2: Securing a Multi-Tier Application
## FinTrust Bank — NSGs, ASGs, and User Defined Routes
### Time: 50 Minutes

---

## Scenario

FinTrust Bank is migrating its core banking application to Azure. Due to strict compliance (PCI DSS, SOX), they must enforce:
- Network segmentation between web, app, and database tiers
- Traffic filtering — only allowed ports between specific tiers
- Dynamic VM group policies (not tied to static IPs)
- All traffic from web tier inspected by Azure Firewall

---

## Architecture

```
                        Internet
                            │
                  ┌─────────▼──────────┐
                  │  Azure App Gateway │  (Load Balancer / WAF)
                  └─────────┬──────────┘
                            │ :80 / :443
┌───────────────────────────▼──────────────────────────────────┐
│                    VNet: vnet-fintrust                         │
│                    10.0.0.0/16                                │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  snet-web   (10.0.1.0/24)                               │  │
│  │  NSG: Allow :80/:443 from Internet                      │  │
│  │  ASG: asg-web-servers                                   │  │
│  │  Route Table → Azure Firewall (10.0.4.4)                │  │
│  │  [VM: web-server-1] [VM: web-server-2]                  │  │
│  └─────────────────────────┬───────────────────────────────┘  │
│                            │ :8080 (ASG-based rule)            │
│  ┌─────────────────────────▼───────────────────────────────┐  │
│  │  snet-app   (10.0.2.0/24)                               │  │
│  │  NSG: Allow :8080 from asg-web-servers only             │  │
│  │  ASG: asg-app-servers                                   │  │
│  │  [VM: app-server-1] [VM: app-server-2]                  │  │
│  └─────────────────────────┬───────────────────────────────┘  │
│                            │ :1433 (ASG-based rule)            │
│  ┌─────────────────────────▼───────────────────────────────┐  │
│  │  snet-db    (10.0.3.0/24)                               │  │
│  │  NSG: Allow :1433 from asg-app-servers only             │  │
│  │  ASG: asg-db-servers                                    │  │
│  │  [VM: db-server-1]                                      │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  AzureFirewallSubnet (10.0.4.0/26) — Required name      │  │
│  │  Azure Firewall IP: 10.0.4.4                            │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

---

## NSG Rules Summary

### Web Subnet NSG (`nsg-web`)
| Priority | Rule Name | Port | Source | Action |
|----------|-----------|------|--------|--------|
| 100 | Allow-HTTP | 80 | Internet | Allow |
| 110 | Allow-HTTPS | 443 | Internet | Allow |
| 200 | Allow-LB-Probes | * | AzureLoadBalancer | Allow |
| 300 | Allow-SSH-Admin | 22 | * | Allow |
| 4096 | Deny-All | * | * | Deny |

### App Subnet NSG (`nsg-app`)
| Priority | Rule Name | Port | Source | Action |
|----------|-----------|------|--------|--------|
| 100 | Allow-App-From-Web-ASG | 8080 | ASG:asg-web-servers | Allow |
| 200 | Deny-Internet | * | Internet | Deny |
| 4096 | Deny-All | * | * | Deny |

### DB Subnet NSG (`nsg-db`)
| Priority | Rule Name | Port | Source | Action |
|----------|-----------|------|--------|--------|
| 100 | Allow-SQL-From-App-ASG | 1433 | ASG:asg-app-servers | Allow |
| 200 | Deny-Internet | * | Internet | Deny |
| 4096 | Deny-All | * | * | Deny |

---

## Files

```
case-study-2/
├── README.md                   ← This file
├── arm/
│   └── network-security.json   ← Full ARM template for 3-tier network
└── scripts/
    ├── deploy.sh               ← Deploys the full 3-tier network
    └── validate.sh             ← Validates NSG rules and connectivity
```

---

## Step-by-Step Lab Guide

### Step 1: Deploy the 3-Tier Network (20 mins)

```bash
# Create resource group
az group create \
  --name rg-fintrust-prod \
  --location eastus \
  --tags environment=prod project=fintrust compliance=pci-dss

# Deploy the full ARM template
az deployment group create \
  --name "fintrust-deploy-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-fintrust-prod \
  --template-file case-study-2/arm/network-security.json \
  --parameters prefix=fintrust location=eastus

# Verify
az resource list --resource-group rg-fintrust-prod --output table
```

---

### Step 2: Inspect NSG Rules (5 mins)

```bash
# Web NSG rules
echo "=== WEB SUBNET NSG ==="
az network nsg rule list \
  --resource-group rg-fintrust-prod \
  --nsg-name nsg-web-fintrust \
  --output table

# App NSG rules
echo "=== APP SUBNET NSG ==="
az network nsg rule list \
  --resource-group rg-fintrust-prod \
  --nsg-name nsg-app-fintrust \
  --output table

# DB NSG rules
echo "=== DB SUBNET NSG ==="
az network nsg rule list \
  --resource-group rg-fintrust-prod \
  --nsg-name nsg-db-fintrust \
  --output table
```

---

### Step 3: Inspect ASGs (5 mins)

```bash
# List Application Security Groups
az network asg list \
  --resource-group rg-fintrust-prod \
  --output table

# Show how ASG is referenced in an NSG rule
az network nsg rule show \
  --resource-group rg-fintrust-prod \
  --nsg-name nsg-app-fintrust \
  --name Allow-App-From-Web-ASG \
  --output jsonc
```

**Discussion point:** Notice the rule references `asg-web-servers` by ID, not by IP. When you add/remove VMs from the ASG, the rule doesn't change.

---

### Step 4: Configure UDR (10 mins)

```bash
# Create a route table for the web tier
az network route-table create \
  --resource-group rg-fintrust-prod \
  --name rt-web-tier \
  --location eastus \
  --disable-bgp-route-propagation true

# Add default route via firewall
az network route-table route create \
  --resource-group rg-fintrust-prod \
  --route-table-name rt-web-tier \
  --name route-all-to-firewall \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.4.4

# Associate route table with web subnet
az network vnet subnet update \
  --resource-group rg-fintrust-prod \
  --vnet-name vnet-fintrust \
  --name snet-web \
  --route-table rt-web-tier

# Verify the route table is associated
az network vnet subnet show \
  --resource-group rg-fintrust-prod \
  --vnet-name vnet-fintrust \
  --name snet-web \
  --query 'routeTable'
```

---

### Step 5: Run Validation Script (5 mins)

```bash
chmod +x case-study-2/scripts/validate.sh
./case-study-2/scripts/validate.sh rg-fintrust-prod fintrust
```

This script checks:
- All NSGs exist and are associated with subnets
- Critical NSG rules are in place
- ASGs are created
- Route table is associated with web subnet

---

## Cleanup

```bash
az group delete --name rg-fintrust-prod --yes --no-wait
```

---

## Key Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| Network segmentation | 3 subnets with distinct NSGs |
| Least-privilege firewall rules | Explicit deny-all + allowlist |
| Dynamic grouping with ASG | Rules reference ASG names, not IPs |
| Traffic inspection with UDR | Route table forces traffic through firewall |
| Compliance-ready architecture | PCI DSS 3-tier isolation pattern |
