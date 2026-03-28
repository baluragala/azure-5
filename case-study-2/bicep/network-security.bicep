// ============================================================
// FinTrust Bank — 3-Tier Network Security
// Bicep equivalent of ../arm/network-security.json
//
// KEY DIFFERENCE FROM ARM:
//   - No explicit dependsOn — Bicep resolves dependencies automatically
//     via symbolic resource references (e.g. asgWeb.id)
//   - String interpolation instead of concat()
//   - Cleaner, more readable syntax
// ============================================================

// ---------- Parameters ----------

@description('Short prefix for resource names (e.g. fintrust).')
@maxLength(15)
param prefix string = 'fintrust'

@description('Azure region.')
param location string = resourceGroup().location

@description('VNet address space.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Web tier subnet CIDR.')
param webSubnetPrefix string = '10.0.1.0/24'

@description('App tier subnet CIDR.')
param appSubnetPrefix string = '10.0.2.0/24'

@description('DB tier subnet CIDR.')
param dbSubnetPrefix string = '10.0.3.0/24'

@description('Azure Firewall subnet. MUST be named AzureFirewallSubnet and /26 or larger.')
param firewallSubnetPrefix string = '10.0.4.0/26'

// ---------- Variables ----------

var vnetName = 'vnet-${prefix}'
var nsgWebName = 'nsg-web-${prefix}'
var nsgAppName = 'nsg-app-${prefix}'
var nsgDbName = 'nsg-db-${prefix}'
var routeTableWebName = 'rt-web-${prefix}'

// ---------- Application Security Groups ----------

resource asgWeb 'Microsoft.Network/applicationSecurityGroups@2023-04-01' = {
  name: 'asg-web-servers'
  location: location
  tags: {
    tier: 'web'
    project: prefix
    purpose: 'Groups all web-tier VMs for NSG rule targeting'
  }
  properties: {}
}

resource asgApp 'Microsoft.Network/applicationSecurityGroups@2023-04-01' = {
  name: 'asg-app-servers'
  location: location
  tags: {
    tier: 'app'
    project: prefix
    purpose: 'Groups all app-tier VMs for NSG rule targeting'
  }
  properties: {}
}

resource asgDb 'Microsoft.Network/applicationSecurityGroups@2023-04-01' = {
  name: 'asg-db-servers'
  location: location
  tags: {
    tier: 'db'
    project: prefix
    purpose: 'Groups all database VMs for NSG rule targeting'
  }
  properties: {}
}

// ---------- NSG: Web Tier ----------

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgWebName
  location: location
  tags: {
    tier: 'web'
    project: prefix
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-From-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgWeb.id }  // Bicep resolves dependency on asgWeb automatically
          ]
          destinationPortRange: '80'
          description: 'HTTP from Internet to web servers (via ASG)'
        }
      }
      {
        name: 'Allow-HTTPS-From-Internet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgWeb.id }
          ]
          destinationPortRange: '443'
          description: 'HTTPS from Internet to web servers (via ASG)'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Required for ALB health probes'
        }
      }
      {
        name: 'Allow-SSH-For-Admin'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgWeb.id }
          ]
          destinationPortRange: '22'
          description: 'SSH. In production, restrict sourceAddressPrefix to your admin IP.'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit deny all. Required for zero-trust compliance.'
        }
      }
    ]
  }
}

// ---------- NSG: App Tier — ASG-based source rules ----------

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAppName
  location: location
  tags: {
    tier: 'app'
    project: prefix
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-App-From-Web-ASG'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            { id: asgWeb.id }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgApp.id }
          ]
          destinationPortRange: '8080'
          description: 'App tier port 8080 — only reachable from web servers. No IP addresses needed.'
        }
      }
      {
        name: 'Deny-Internet-Direct-Access'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'App tier must NEVER be directly reachable from Internet'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit deny all'
        }
      }
    ]
  }
}

// ---------- NSG: DB Tier — SQL access only from app servers ----------

resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgDbName
  location: location
  tags: {
    tier: 'db'
    project: prefix
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-SQL-From-App-ASG'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            { id: asgApp.id }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgDb.id }
          ]
          destinationPortRange: '1433'
          description: 'SQL Server port — ONLY from app servers. Never from web or Internet.'
        }
      }
      {
        name: 'Deny-Internet-Direct-Access'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Database must NEVER be directly reachable from Internet'
        }
      }
      {
        name: 'Deny-Web-Tier-Direct'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Web servers must never talk directly to DB. Must go through App tier.'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit deny all'
        }
      }
    ]
  }
}

// ---------- Route Table: Web Tier — forces all traffic through Firewall ----------

resource routeTableWeb 'Microsoft.Network/routeTables@2023-04-01' = {
  name: routeTableWebName
  location: location
  tags: {
    tier: 'web'
    project: prefix
    purpose: 'Force web tier outbound traffic through Azure Firewall for inspection'
  }
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'route-all-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.4.4'
          description: 'Default route: all outbound traffic goes through Azure Firewall'
        }
      }
      {
        name: 'route-vnet-to-firewall'
        properties: {
          addressPrefix: vnetAddressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.4.4'
          description: 'East-West VNet traffic also goes through Firewall'
        }
      }
    ]
  }
}

// ---------- Virtual Network with 3-tier subnets ----------
// Bicep automatically infers dependencies via .id references below

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: {
    project: prefix
    compliance: 'pci-dss'
    architecture: '3-tier'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: { id: nsgWeb.id }
          routeTable: { id: routeTableWeb.id }
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: { id: nsgApp.id }
        }
      }
      {
        name: 'snet-db'
        properties: {
          addressPrefix: dbSubnetPrefix
          networkSecurityGroup: { id: nsgDb.id }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
    ]
  }
}

// ---------- Outputs ----------

@description('VNet resource ID')
output vnetId string = vnet.id

@description('VNet name')
output vnetName string = vnet.name

@description('Web subnet resource ID')
output webSubnetId string = vnet.properties.subnets[0].id

@description('App subnet resource ID')
output appSubnetId string = vnet.properties.subnets[1].id

@description('DB subnet resource ID')
output dbSubnetId string = vnet.properties.subnets[2].id

@description('Web ASG resource ID')
output asgWebId string = asgWeb.id

@description('App ASG resource ID')
output asgAppId string = asgApp.id

@description('DB ASG resource ID')
output asgDbId string = asgDb.id
