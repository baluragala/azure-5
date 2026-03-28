// ============================================================
// Module: peer-link.bicep
//
// Creates ONE side of a VNet peering link.
// VNet peering is bidirectional but each direction must be
// declared as a separate Azure resource.  Deploy this module
// twice — once per VNet — to get a full two-way peering.
// ============================================================

// ---------- Parameters ----------

@description('Name of the local VNet (must exist in the resource group this module is deployed to).')
param localVnetName string

@description('Full resource ID of the remote VNet to peer with.')
param remoteVnetId string

@description('Name for this peering link, e.g. "peer-primary-to-dr".')
param peeringName string

@description('Allow VMs in both VNets to communicate with each other.')
param allowVirtualNetworkAccess bool = true

@description('Allow forwarded traffic (needed when chaining peerings or using NVAs).')
param allowForwardedTraffic bool = true

@description('Allow this VNet to use the remote VNet\'s gateway (set true only on spoke, never on hub).')
param useRemoteGateways bool = false

@description('Allow the remote VNet to use this VNet\'s gateway (set true only on hub, never on spoke).')
param allowGatewayTransit bool = false

// ---------- Resources ----------

// Reference the local VNet — it must already exist.
// "existing" tells Bicep "don't create this, just get its resource ID".
resource localVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: localVnetName
}

// One directional peering link (Local → Remote).
// Azure requires a matching link on the remote side; that is created
// by a second invocation of this same module in the parent template.
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId      // The remote VNet's full ARM resource ID
    }
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}

// ---------- Outputs ----------

@description('Resource ID of the peering link just created.')
output peeringId string = peering.id

@description('Peering state: Initiated | Connected | Disconnected. Both sides must show Connected.')
output peeringState string = peering.properties.peeringState
