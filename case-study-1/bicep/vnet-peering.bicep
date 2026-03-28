// ============================================================
// vnet-peering.bicep
// SecureInsure — VNet Peering: Primary (East US) ↔ DR (East US 2)
//
// WHAT:
//   Establishes private, low-latency network connectivity between
//   the primary region VNet and the Disaster Recovery VNet without
//   traffic ever leaving the Azure backbone.
//
// WHY:
//   After Step 7 of the lab, two isolated VNets exist in separate
//   resource groups and regions.  Resources in those VNets cannot
//   talk to each other.  VNet peering solves this so that:
//     - DR standby VMs can replicate data from primary VMs.
//     - A failover can happen with no routing changes.
//     - No VPN gateway cost or latency is introduced.
//
// HOW (Azure internals):
//   1. A peering resource is created under each VNet (two resources total).
//   2. Azure updates the effective routes on every NIC in both VNets
//      to add the remote address space as a "VNet Peering" next-hop.
//   3. Traffic is routed over Microsoft's private backbone — never
//      the public Internet.
//   4. Both links must reach "Connected" state before traffic flows.
//
// DEPLOYMENT SCOPE:
//   This file uses targetScope = 'subscription' so it can deploy
//   resources into two different resource groups in one operation.
//   Each peering link is created via the peer-link module scoped
//   to its own resource group.
//
// PREREQUISITE:
//   Both VNets must be deployed first (Steps 2 and 7 of the lab).
//   Address spaces must NOT overlap (10.1.0.0/16 vs 10.2.0.0/16).
// ============================================================

targetScope = 'subscription'

// ---------- Parameters ----------

@description('Resource group that contains the primary (East US) VNet.')
param primaryResourceGroup string = 'rg-secureinsure-dev'

@description('Resource group that contains the DR (East US 2) VNet.')
param drResourceGroup string = 'rg-secureinsure-dr'

@description('Name of the primary VNet.  Must match the name used when it was deployed.')
param primaryVnetName string = 'secureinsure-vnet-dev'

@description('Name of the DR VNet.  Must match the name used when it was deployed.')
param drVnetName string = 'secureinsure-vnet-prod'

// ---------- Existing VNet references ----------
//
// "existing" means Bicep will look these up (to get their IDs) without
// trying to create or modify them.  scope: resourceGroup(...) tells
// Bicep which resource group each one lives in.

resource primaryVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: primaryVnetName
  scope: resourceGroup(primaryResourceGroup)
}

resource drVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: drVnetName
  scope: resourceGroup(drResourceGroup)
}

// ---------- Peering links ----------
//
// Azure VNet peering is DIRECTIONAL — each side must be created
// independently.  Think of it like a two-way street: you need a lane
// in each direction.  Both lanes must exist for traffic to flow.

// Link 1 of 2 — Primary → DR
// Deployed into the primary resource group (where primaryVnet lives).
module primaryToDr 'modules/peer-link.bicep' = {
  name: 'peer-primary-to-dr'
  scope: resourceGroup(primaryResourceGroup)
  params: {
    localVnetName: primaryVnetName
    remoteVnetId: drVnet.id        // drVnet.id is resolved from the "existing" reference above
    peeringName: 'peer-to-dr'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false     // Primary is not a hub gateway in this lab
    useRemoteGateways: false
  }
}

// Link 2 of 2 — DR → Primary
// Deployed into the DR resource group (where drVnet lives).
// Without this second link, the peering stays in "Initiated" state and
// traffic does NOT flow.
module drToPrimary 'modules/peer-link.bicep' = {
  name: 'peer-dr-to-primary'
  scope: resourceGroup(drResourceGroup)
  params: {
    localVnetName: drVnetName
    remoteVnetId: primaryVnet.id   // primaryVnet.id from the "existing" reference above
    peeringName: 'peer-to-primary'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ---------- Outputs ----------

@description('Peering state of the Primary → DR link.  Must be "Connected" before traffic flows.')
output primaryToDrState string = primaryToDr.outputs.peeringState

@description('Peering state of the DR → Primary link.  Must be "Connected" before traffic flows.')
output drToPrimaryState string = drToPrimary.outputs.peeringState

@description('Resource ID of the Primary → DR peering link.')
output primaryToDrPeeringId string = primaryToDr.outputs.peeringId

@description('Resource ID of the DR → Primary peering link.')
output drToPrimaryPeeringId string = drToPrimary.outputs.peeringId
