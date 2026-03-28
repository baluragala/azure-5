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
├── README.md                    ← This file
├── arm/
│   ├── main.json                ← Full ARM template (parameterized)
│   ├── params.dev.json          ← Dev environment parameters
│   ├── params.staging.json      ← Staging parameters
│   └── params.prod.json         ← Production parameters
├── bicep/
│   ├── main.bicep               ← Bicep version of the ARM template
│   ├── main.bicepparam          ← Bicep parameter file
│   ├── vnet-peering.bicep       ← VNet peering: Primary ↔ DR (subscription scope)
│   └── modules/
│       └── peer-link.bicep      ← Reusable module: one directional peering link
└── scripts/
    ├── deploy-arm.sh            ← Full ARM deployment script
    └── deploy-bicep.sh          ← Bicep deployment script
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

---

## VNet Peering: Connecting Primary and DR Networks

### What is VNet Peering?

VNet Peering is Azure's mechanism for connecting two Virtual Networks so that resources in both VNets can communicate using **private IP addresses**, as if they were on the same network.

```
East US (Primary)                    East US 2 (DR)
┌──────────────────────┐             ┌──────────────────────┐
│ rg-secureinsure-dev  │             │ rg-secureinsure-dr   │
│ ┌──────────────────┐ │             │ ┌──────────────────┐ │
│ │ VNet 10.1.0.0/16 │ │◄───────────►│ │ VNet 10.2.0.0/16 │ │
│ │                  │ │  Peering    │ │                  │ │
│ │  web-server VM   │ │  (private   │ │  dr-standby VM   │ │
│ │  10.1.1.4        │ │   backbone) │ │  10.2.1.4        │ │
│ └──────────────────┘ │             │ └──────────────────┘ │
└──────────────────────┘             └──────────────────────┘
```

Traffic travels over **Microsoft's private backbone** — it never touches the public Internet.

---

### Why Use VNet Peering?

| Without Peering | With VNet Peering |
|----------------|-------------------|
| VMs in different VNets cannot reach each other privately | Full private connectivity between VNets |
| DR replication requires public IPs or VPN | DR replication over private IPs, no VPN cost |
| Failover requires DNS/routing changes | No routing changes needed on failover |
| VPN gateway adds ~$140+/month | Peering is billed per GB transferred, no gateway fee |
| VPN adds 1-5ms latency | Near-LAN latency over the Azure backbone |

**For SecureInsure's DR strategy, peering enables:**
- Database replication from primary to DR at low latency
- Application health checks across regions without public exposure
- Seamless failover — the DR VM already knows the primary's private IPs

---

### How VNet Peering Works (Internals)

1. **Two peering resources are created** — one under each VNet. Azure requires both sides to be established before traffic flows. A single-sided peering stays in `Initiated` state and carries no traffic.

2. **Azure injects routes automatically.** Once both sides are `Connected`, Azure's SDN layer adds a route to every NIC in both VNets: remote address space → next-hop type `VNetPeering`. You do not manage route tables manually.

3. **Address spaces must not overlap.** You cannot peer `10.1.0.0/16` with `10.1.0.0/16`. This is why `main.bicep` uses different CIDR blocks per region (`10.1.x.x` primary, `10.2.x.x` DR).

4. **Peering is non-transitive by default.** If VNet A peers with VNet B, and B peers with C, A cannot reach C through B. Hub-spoke architectures handle this with Azure Firewall or NVAs.

**State machine:**

```
  Primary side created     →  State: Initiated
  DR side also created     →  State: Connected  ← traffic flows here
  Either side deleted      →  State: Disconnected
```

---

### Bicep Design: Why Two Files?

VNet peering requires a resource to be deployed under **each** VNet, and each VNet lives in a **different resource group**. Bicep's `targetScope = 'subscription'` lets a single template deploy to multiple resource groups via modules.

```
vnet-peering.bicep          ← targetScope = 'subscription'
│                               references both VNets as "existing"
├── module primaryToDr      ← scope: resourceGroup(primaryRG)
│       peer-link.bicep         creates "peer-to-dr" under primary VNet
│
└── module drToPrimary      ← scope: resourceGroup(drRG)
        peer-link.bicep         creates "peer-to-primary" under DR VNet
```

`peer-link.bicep` is a reusable module — it takes a local VNet name and a remote VNet ID, and creates exactly one directional peering link. The same module is called twice with swapped arguments to make the connection bidirectional.

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

### Step 8: Deploy VNet Peering (5 mins)

```bash
# vnet-peering.bicep uses targetScope = 'subscription', so we deploy
# at subscription level (not resource group level).
az deployment sub create \
  --name "deploy-peering-$(date +%Y%m%d-%H%M%S)" \
  --location eastus \
  --template-file case-study-1/bicep/vnet-peering.bicep \
  --parameters \
      primaryResourceGroup=rg-secureinsure-dev \
      drResourceGroup=rg-secureinsure-dr \
      primaryVnetName=secureinsure-vnet-dev \
      drVnetName=secureinsure-vnet-prod
```

**Verify the peering is Connected on both sides:**

```bash
# Check primary side (Primary → DR)
az network vnet peering list \
  --resource-group rg-secureinsure-dev \
  --vnet-name secureinsure-vnet-dev \
  --output table

# Check DR side (DR → Primary)
az network vnet peering list \
  --resource-group rg-secureinsure-dr \
  --vnet-name secureinsure-vnet-prod \
  --output table
```

Both rows should show `peeringState = Connected`.

**Test private connectivity (optional — requires VMs in both VNets):**

```bash
# SSH into the primary VM, then ping the DR VM's private IP
# The DR VM's private IP will be in the 10.2.1.x range
ping 10.2.1.4

# If ping is blocked by NSG, test TCP instead:
nc -zv 10.2.1.4 22
```

**What to observe:**
- Without peering: ping times out (no route exists)
- With peering: ping succeeds via private IP, no public Internet involved
- `az network vnet peering show` → check `peeringState`, `remoteAddressSpace`

---

## Cleanup

```bash
# Peering is deleted automatically when the resource group is deleted.
# Delete resource groups in any order — Azure handles the dangling peering references.
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
| VNet Peering (what/why/how) | VNet Peering section above |
| Cross-RG Bicep deployment | `vnet-peering.bicep` with `targetScope = 'subscription'` |
| Bicep modules | `modules/peer-link.bicep` called twice with different scopes |
| Existing resource references | `resource ... existing = { scope: resourceGroup(...) }` |
