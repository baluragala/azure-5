# Case Study 1: Enterprise-Grade Infrastructure Deployment
## SecureInsure — ARM Templates & Bicep
### Time: 50 Minutes

---

## Scenario

SecureInsure, a multinational insurance firm, wants to:
- Deploy a highly available web application across **two Azure regions**
- Use **parameterized ARM templates** for dev/staging/production consistency
- **Convert to Bicep** for better developer experience
- Deploy and validate via **Azure CLI**

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Multi-Region Deployment                   │
│                                                             │
│   East US (Primary)           West US (DR)                  │
│   ┌─────────────────┐         ┌─────────────────┐           │
│   │ rg-secureinsure │         │ rg-secureinsure  │           │
│   │      -dev       │         │      -dr         │           │
│   │ ┌─────────────┐ │         │ ┌─────────────┐  │           │
│   │ │ VNet        │ │         │ │ VNet        │  │           │
│   │ │ 10.1.0.0/16 │ │         │ │ 10.2.0.0/16 │  │           │
│   │ │ ┌─────────┐ │ │         │ │ ┌─────────┐  │  │           │
│   │ │ │web-snet │ │ │         │ │ │web-snet │  │  │           │
│   │ │ │app-snet │ │ │         │ │ │app-snet │  │  │           │
│   │ │ └─────────┘ │ │         │ │ └─────────┘  │  │           │
│   │ │ NSG (web)   │ │         │ │ NSG (web)    │  │           │
│   │ └─────────────┘ │         │ └─────────────┘  │           │
│   │ VM: web-server  │         │ VM: dr-standby   │           │
│   └─────────────────┘         └─────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

---

## What's Deployed

| Resource | Purpose |
|----------|---------|
| Virtual Network | Network isolation with address space |
| Web Subnet | Hosts web-tier VMs |
| App Subnet | Hosts application-tier VMs |
| NSG (Web) | Allows HTTP/HTTPS, blocks everything else |
| NSG (App) | Allows traffic from web subnet only |
| Public IP | For VM access during demo |
| VM (Ubuntu) | Example workload |

---

## Files in This Directory

```
case-study-1/
├── README.md                ← This file
├── arm/
│   ├── main.json            ← Full ARM template (parameterized)
│   ├── params.dev.json      ← Dev environment parameters
│   ├── params.staging.json  ← Staging parameters
│   └── params.prod.json     ← Production parameters
├── bicep/
│   ├── main.bicep           ← Bicep version of the ARM template
│   └── main.bicepparam      ← Bicep parameter file
└── scripts/
    ├── deploy-arm.sh        ← Full ARM deployment script
    └── deploy-bicep.sh      ← Bicep deployment script
```

---

## Step-by-Step Lab Guide

### Prerequisites
```bash
# Verify Azure CLI is installed
az --version

# Log in
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "<your-subscription-id>"
```

---

### Step 1: Explore the ARM Template (5 mins)

Open `arm/main.json` and identify these sections:

```bash
# View the template structure
cat case-study-1/arm/main.json | python3 -m json.tool | head -80
```

**Key questions to discuss:**
- What parameters does it accept?
- What resources does it create?
- What are the `dependsOn` relationships?

---

### Step 2: Deploy to Dev Environment (10 mins)

```bash
# Create the resource group
az group create \
  --name rg-secureinsure-dev \
  --location eastus \
  --tags environment=dev project=secureinsure

# Deploy the ARM template with dev parameters
az deployment group create \
  --name "deploy-dev-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-secureinsure-dev \
  --template-file case-study-1/arm/main.json \
  --parameters @case-study-1/arm/params.dev.json \
  --verbose

# Watch deployment progress
az deployment group list \
  --resource-group rg-secureinsure-dev \
  --output table
```

---

### Step 3: Verify Deployed Resources (5 mins)

```bash
# List all resources
az resource list \
  --resource-group rg-secureinsure-dev \
  --output table

# Check VNet details
az network vnet list \
  --resource-group rg-secureinsure-dev \
  --output table

# Check NSG rules
az network nsg rule list \
  --resource-group rg-secureinsure-dev \
  --nsg-name nsg-web-dev \
  --output table
```

---

### Step 4: Deploy to Staging (Same Template, Different Params) (5 mins)

```bash
# This proves the template is reusable!
az group create --name rg-secureinsure-staging --location eastus

az deployment group create \
  --name "deploy-staging-$(date +%Y%m%d-%H%M%S)" \
  --resource-group rg-secureinsure-staging \
  --template-file case-study-1/arm/main.json \
  --parameters @case-study-1/arm/params.staging.json
```

---

### Step 5: Explore Bicep Version (10 mins)

```bash
# View the Bicep template
cat case-study-1/bicep/main.bicep

# Compare line count (Bicep is ~40% shorter)
wc -l case-study-1/arm/main.json
wc -l case-study-1/bicep/main.bicep

# (Optional) Decompile ARM to Bicep automatically
az bicep decompile --file case-study-1/arm/main.json --outfile /tmp/decompiled.bicep
cat /tmp/decompiled.bicep
```

---

### Step 6: Deploy with Bicep (10 mins)

```bash
# Deploy the Bicep template directly
az group create --name rg-secureinsure-bicep-demo --location eastus

az deployment group create \
  --resource-group rg-secureinsure-bicep-demo \
  --template-file case-study-1/bicep/main.bicep \
  --parameters environment=dev location=eastus prefix=secureinsure vnetAddressPrefix=10.3.0.0/16
```

---

### Step 7: Multi-Region DR Deployment (5 mins)

```bash
# Deploy to West US as Disaster Recovery
az group create --name rg-secureinsure-dr --location eastus2

az deployment group create \
  --resource-group rg-secureinsure-dr \
  --template-file case-study-1/bicep/main.bicep \
  --parameters environment=prod location=eastus2 prefix=secureinsure vnetAddressPrefix=10.2.0.0/16

# Verify both regions are deployed
az group list \
  --query "[?starts_with(name,'rg-secureinsure')]" \
  --output table
```

---

## Cleanup

```bash
az group delete --name rg-secureinsure-dev --yes --no-wait
az group delete --name rg-secureinsure-staging --yes --no-wait
az group delete --name rg-secureinsure-bicep-demo --yes --no-wait
az group delete --name rg-secureinsure-dr --yes --no-wait
```

---

## Key Concepts Demonstrated

| Concept | Where Demonstrated |
|---------|-------------------|
| Parameterized templates | `params.dev/staging/prod.json` |
| Resource dependencies | `dependsOn` in ARM, implicit in Bicep |
| Multi-environment reuse | Same template, 3 different param files |
| ARM → Bicep migration | `az bicep decompile` command |
| Multi-region deployment | Two separate deployments, different `location` |
