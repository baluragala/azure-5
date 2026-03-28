# Introduction to Azure - II
## Live Session Slides
### Duration: 2 Hours 30 Minutes

---

# PART I: INTRODUCTION
## (10 Minutes)

---

## Slide 1 — Welcome

**Session: Introduction to Azure - II**

**Today's Journey:**
- From manual resource creation → automated, scalable infrastructure
- From static IPs → intelligent, dynamic security policies
- From single-region → multi-region, highly available deployments

**Instructor Note:** Introduce yourself. Ask learners to open Azure Portal and Cloud Shell.

---

## Slide 2 — Session Objective

> "By the end of this session, you will be able to automate Azure infrastructure using ARM templates and Bicep, and enforce enterprise-grade network security using NSGs, ASGs, and UDRs."

**What we'll build today:**
1. A multi-region, parameterized infrastructure (ARM + Bicep)
2. A 3-tier secure network for a banking application

---

## Slide 3 — Quick Recap: What Did We Cover Before?

| Previous Session | Today's Session |
|-----------------|-----------------|
| Azure basics, VMs, Storage | ARM Templates + Bicep |
| Azure Portal (manual) | Infrastructure as Code (IaC) |
| Single VNet | Multi-region VNets |
| Basic NSGs | NSGs + ASGs + UDRs |

**Instructor Note:** Spend 2 mins asking learners what they remember.

---

## Slide 4 — Agenda Overview

```
10 mins  ──  Part I:   Introduction
50 mins  ──  Part II:  Case Study 1 (ARM + Bicep)
             ├── Scenario walkthrough       (5 min)
             ├── ARM template hands-on      (20 min)
             ├── Bicep conversion           (15 min)
             └── Deploy & validate          (10 min)
50 mins  ──  Part II:  Case Study 2 (NSGs, ASGs, UDRs)
             ├── Scenario walkthrough       (5 min)
             ├── 3-tier network design      (10 min)
             ├── NSG + ASG configuration    (20 min)
             ├── UDR + Routing              (10 min)
             └── Security validation        (5 min)
10 mins  ──  Part III: Summary + Q&A
```

---

# PART II — CASE STUDY 1
## Enterprise Infrastructure with ARM Templates & Bicep
### (50 Minutes)

---

## Slide 5 — The Problem: Manual Deployments Don't Scale

**Pain Points of Manual Deployment:**
- Inconsistent environments (dev ≠ prod)
- Human errors during repetitive deployments
- No audit trail for infrastructure changes
- Cannot replicate easily across regions

**Solution: Infrastructure as Code (IaC)**
> "Define your infrastructure in code, version it like software, deploy it consistently every time."

---

## Slide 6 — Case Study 1: SecureInsure

**Company:** SecureInsure — Multinational Insurance Firm

**The Challenge:**
- Modernizing IT infrastructure
- Need to deploy across **two Azure regions** (Primary + DR)
- Maintain consistency across dev, staging, and production
- Infrastructure must be **repeatable and auditable**

**Our Tasks:**
1. Build modular ARM templates (parameterized)
2. Convert to Bicep
3. Deploy using Azure CLI

---

## Slide 7 — What is an ARM Template?

**ARM = Azure Resource Manager**

```json
{
  "$schema": "https://schema.management.azure.com/schemas/...",
  "contentVersion": "1.0.0.0",
  "parameters": { },    ← Inputs (environment-specific values)
  "variables": { },     ← Computed values
  "resources": [ ],     ← What to create
  "outputs": { }        ← Return values
}
```

**Key Benefits:**
- Idempotent (run multiple times, same result)
- Declarative (say WHAT, not HOW)
- Supports dependencies (`dependsOn`)
- Rollback on failure

---

## Slide 8 — ARM Template Architecture (Case Study 1)

```
SecureInsure Multi-Region Architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Region: East US                Region: West US (DR)
  ┌────────────────────┐         ┌────────────────────┐
  │  Resource Group    │         │  Resource Group     │
  │  ┌──────────────┐  │         │  ┌──────────────┐   │
  │  │  VNet        │  │         │  │  VNet        │   │
  │  │  10.1.0.0/16 │  │◄──────►│  │  10.2.0.0/16 │   │
  │  │  ┌────────┐  │  │  VNet   │  │  ┌────────┐  │   │
  │  │  │ Web SN │  │  │ Peering │  │  │ Web SN │  │   │
  │  │  │ App SN │  │  │         │  │  │ App SN │  │   │
  │  │  └────────┘  │  │         │  │  └────────┘  │   │
  │  │  NSG attached│  │         │  │  NSG attached│   │
  │  └──────────────┘  │         │  └──────────────┘   │
  │  VM (Web Server)   │         │  VM (DR Standby)    │
  └────────────────────┘         └────────────────────┘
```

---

## Slide 9 — ARM Template: Key Sections Explained

**Parameters** — What changes between environments:
```json
"vmSize": {
  "type": "string",
  "defaultValue": "Standard_B2ms",
  "allowedValues": ["Standard_B1ms", "Standard_B2ms", "Standard_B4ms", "Standard_D2_v3"]
}
```

**Variables** — Derived values (don't repeat yourself):
```json
"vnetName": "[concat(parameters('prefix'), '-vnet')]"
```

**Resources** — The actual Azure resources

**DependsOn** — Ordering:
```json
"dependsOn": ["[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]"]
```

---

## Slide 10 — What is Azure Bicep?

**Bicep = ARM Templates, but human-friendly**

| Feature | ARM Template | Bicep |
|---------|-------------|-------|
| Format | JSON | DSL (Domain Specific Language) |
| Verbosity | High | Low (~40% fewer lines) |
| Intellisense | Limited | Excellent (VS Code) |
| Dependency resolution | Manual (`dependsOn`) | Automatic |
| Loops | Complex `copy` | Simple `for` loops |
| Modules | Linked templates | `module` keyword |

**Same result, better developer experience.**

---

## Slide 11 — ARM vs Bicep Side-by-Side

**ARM Template (JSON):**
```json
{
  "type": "Microsoft.Network/virtualNetworks",
  "apiVersion": "2023-04-01",
  "name": "[variables('vnetName')]",
  "location": "[parameters('location')]",
  "properties": {
    "addressSpace": {
      "addressPrefixes": ["[parameters('vnetAddressPrefix')]"]
    }
  }
}
```

**Bicep equivalent:**
```bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
  }
}
```

**Instructor Note:** Highlight: no quotes around resource names, cleaner syntax.

---

## Slide 12 — HANDS-ON 1: Deploy with ARM Template (20 mins)

**Step 1: Open Cloud Shell (bash)**
```bash
az login   # skip if using Cloud Shell
```

**Step 2: Create Resource Group**
```bash
az group create --name rg-secureinsure-dev --location eastus
```

**Step 3: Deploy ARM Template**
```bash
az deployment group create \
  --resource-group rg-secureinsure-dev \
  --template-file case-study-1/arm/main.json \
  --parameters @case-study-1/arm/params.dev.json
```

**Step 4: Verify Resources**
```bash
az resource list --resource-group rg-secureinsure-dev --output table
```

> **Instructor Note:** Walk through the ARM template file line by line before running.

---

## Slide 13 — HANDS-ON 2: Convert to Bicep (15 mins)

**Decompile ARM → Bicep (automated conversion):**
```bash
az bicep decompile --file case-study-1/arm/main.json
```

**Or use the pre-written Bicep file:**
```bash
cat case-study-1/bicep/main.bicep
```

**Deploy using Bicep:**
```bash
az deployment group create \
  --resource-group rg-secureinsure-staging \
  --template-file case-study-1/bicep/main.bicep \
  --parameters environment=staging location=eastus
```

---

## Slide 14 — HANDS-ON 3: Multi-Region Deploy (10 mins)

**Deploy to second region (DR):**
```bash
# Create DR resource group
az group create --name rg-secureinsure-dr --location eastus2

# Deploy with DR parameters
az deployment group create \
  --resource-group rg-secureinsure-dr \
  --template-file case-study-1/bicep/main.bicep \
  --parameters environment=prod location=eastus2 vnetAddressPrefix=10.2.0.0/16
```

**Validate both deployments:**
```bash
az group list --query "[?starts_with(name,'rg-secureinsure')]" --output table
```

---

# PART II — CASE STUDY 2
## Securing a Multi-Tier Application with NSGs, ASGs & UDRs
### (50 Minutes)

---

## Slide 15 — Case Study 2: FinTrust Bank

**Company:** FinTrust Bank — Core Banking Application Migration

**Security Requirements:**
- Zero-trust network segmentation
- Strict compliance: PCI DSS, SOX
- Traffic isolation between tiers
- All traffic audited and logged

**Our Tasks:**
1. Design 3-tier network (Web / App / DB)
2. Apply NSGs with explicit allow/deny rules
3. Implement ASGs for dynamic VM grouping
4. Configure UDRs to route through Azure Firewall

---

## Slide 16 — 3-Tier Architecture Design

```
Internet
    │
    ▼
[Azure Application Gateway / Load Balancer]
    │
    ▼
┌───────────────────────────────────────────┐
│             VNet: 10.0.0.0/16             │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │  Web Tier Subnet: 10.0.1.0/24       │  │
│  │  NSG: Allow :80/:443 from Internet  │  │
│  │  ASG: asg-web-servers               │  │
│  └──────────────┬──────────────────────┘  │
│                 │ Port 8080 only           │
│  ┌──────────────▼──────────────────────┐  │
│  │  App Tier Subnet: 10.0.2.0/24       │  │
│  │  NSG: Allow :8080 from Web only     │  │
│  │  ASG: asg-app-servers               │  │
│  └──────────────┬──────────────────────┘  │
│                 │ Port 1433 only           │
│  ┌──────────────▼──────────────────────┐  │
│  │  DB Tier Subnet: 10.0.3.0/24        │  │
│  │  NSG: Allow :1433 from App only     │  │
│  │  ASG: asg-db-servers                │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

---

## Slide 17 — NSG vs ASG: What's the Difference?

| Feature | NSG (Network Security Group) | ASG (Application Security Group) |
|---------|------------------------------|-----------------------------------|
| Applied to | Subnet or NIC | VMs (grouped logically) |
| Rules based on | IP address / CIDR | ASG name |
| When IP changes | Must update rules | No change needed |
| Use case | Subnet-level filtering | VM-group-level filtering |

**Together they're powerful:**
```
NSG Rule: Allow TCP 8080 from ASG:asg-web-servers TO ASG:asg-app-servers
```
→ No IP addresses needed. Add/remove VMs from ASG dynamically.

---

## Slide 18 — NSG Rules Deep Dive

**Rule Priority:** Lower number = higher priority (100 to 4096)

**Inbound rules for Web Subnet NSG:**
```
Priority | Name              | Port | Source          | Action
100      | Allow-HTTP        | 80   | Internet        | Allow
110      | Allow-HTTPS       | 443  | Internet        | Allow
200      | Allow-LB-Probe    | *    | AzureLoadBalancer | Allow
4096     | Deny-All-Inbound  | *    | *               | Deny
```

**Inbound rules for DB Subnet NSG:**
```
Priority | Name              | Port | Source          | Action
100      | Allow-SQL-from-App| 1433 | ASG:asg-app-servers | Allow
4096     | Deny-All-Inbound  | *    | *               | Deny
```

---

## Slide 19 — User Defined Routes (UDRs)

**Default Azure routing:** Traffic goes directly between subnets.

**Problem:** We want ALL traffic from Web tier inspected by Azure Firewall first.

**Solution: UDR (Route Table)**

```
Route Table: rt-web-tier
┌─────────────────────────────────────────────────┐
│  Destination     │  Next Hop Type   │  Next Hop  │
│  0.0.0.0/0       │  VirtualAppliance│  10.0.4.4  │  ← Firewall IP
│  10.0.0.0/16     │  VirtualAppliance│  10.0.4.4  │  ← Internal traffic
└─────────────────────────────────────────────────┘
```

**Effect:** Every packet from Web subnet → Firewall → inspected → forwarded.

---

## Slide 20 — HANDS-ON 4: Deploy 3-Tier Network (20 mins)

**Step 1: Create Resource Group**
```bash
az group create --name rg-fintrust-prod --location eastus
```

**Step 2: Deploy the 3-tier network**
```bash
az deployment group create \
  --resource-group rg-fintrust-prod \
  --template-file case-study-2/arm/network-security.json \
  --parameters prefix=fintrust location=eastus
```

**Step 3: Verify NSGs**
```bash
az network nsg list \
  --resource-group rg-fintrust-prod \
  --output table
```

---

## Slide 21 — HANDS-ON 5: Validate Security Rules (10 mins)

**Check NSG rules for Web subnet:**
```bash
az network nsg rule list \
  --resource-group rg-fintrust-prod \
  --nsg-name nsg-web \
  --output table
```

**Simulate connectivity check:**
```bash
# Check if port 80 is allowed from Internet to Web subnet
az network watcher check-connectivity \
  --source-resource <web-vm-id> \
  --dest-address 8.8.8.8 \
  --dest-port 80
```

**Run the full validation script:**
```bash
chmod +x case-study-2/scripts/validate.sh
./case-study-2/scripts/validate.sh rg-fintrust-prod
```

---

## Slide 22 — UDR Configuration Hands-On (10 mins)

**Create Route Table:**
```bash
az network route-table create \
  --resource-group rg-fintrust-prod \
  --name rt-web-tier \
  --location eastus

az network route-table route create \
  --resource-group rg-fintrust-prod \
  --route-table-name rt-web-tier \
  --name route-to-firewall \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.4.4
```

**Associate with Web Subnet:**
```bash
az network vnet subnet update \
  --resource-group rg-fintrust-prod \
  --vnet-name vnet-fintrust \
  --name snet-web \
  --route-table rt-web-tier
```

---

# PART III: SUMMARY & DOUBT RESOLUTION
## (10 Minutes)

---

## Slide 23 — What We Built Today

**Case Study 1 (SecureInsure):**
- ✓ Modular, parameterized ARM templates
- ✓ Multi-environment deployments (dev/staging/prod)
- ✓ Bicep — cleaner syntax, same power
- ✓ Multi-region deployments via CLI

**Case Study 2 (FinTrust Bank):**
- ✓ 3-tier network segmentation
- ✓ NSGs with explicit allow/deny rules
- ✓ ASGs for dynamic VM grouping
- ✓ UDRs to route through Azure Firewall

---

## Slide 24 — Key Takeaways

1. **ARM Templates** → Idempotent, declarative IaC for Azure
2. **Bicep** → Cleaner syntax that compiles to ARM (not a replacement, an improvement)
3. **NSGs** → Firewall at subnet/NIC level — always use least privilege
4. **ASGs** → Group VMs logically, not by IP — rules stay stable as infrastructure scales
5. **UDRs** → Override Azure default routing — force traffic through security appliances

---

## Slide 25 — Cleanup (Important!)

**Remove all resources to avoid charges:**
```bash
az group delete --name rg-secureinsure-dev --yes --no-wait
az group delete --name rg-secureinsure-dr --yes --no-wait
az group delete --name rg-fintrust-prod --yes --no-wait
```

**Verify cleanup:**
```bash
az group list --query "[?starts_with(name,'rg-secureinsure') || starts_with(name,'rg-fintrust')]" \
  --output table
```

---

## Slide 26 — What's Next?

**Upcoming Topics:**
- Azure Traffic Manager (global load balancing)
- Azure Site Recovery (disaster recovery)
- Azure DNS (custom domain management)
- Azure Monitor + Log Analytics

**Resources:**
- ARM Templates docs: `learn.microsoft.com/azure/azure-resource-manager/templates`
- Bicep docs: `learn.microsoft.com/azure/azure-resource-manager/bicep`
- Azure CLI reference: `learn.microsoft.com/cli/azure`

---

## Slide 27 — Q&A

**Common Questions to Expect:**

1. "When should I use ARM vs Bicep vs Terraform?"
   → ARM/Bicep for Azure-native; Terraform for multi-cloud

2. "Can NSG rules use FQDNs instead of IPs?"
   → Use Azure Firewall Application Rules for FQDN filtering; NSGs use IPs/ASGs

3. "What's the difference between UDR and Azure Firewall?"
   → UDR is routing; Azure Firewall is the inspection engine. Use both together.

4. "Is Bicep production-ready?"
   → Yes, fully supported by Microsoft since 2021. Recommended over raw ARM.

---

*End of Slides*
