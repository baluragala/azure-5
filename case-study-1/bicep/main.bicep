// ============================================================
// SecureInsure — Multi-Region Infrastructure
// Bicep equivalent of the ARM template in ../arm/main.json
//
// KEY DIFFERENCE FROM ARM:
//   - No explicit dependsOn needed (Bicep resolves automatically)
//   - No concatenation functions — use string interpolation: '${prefix}-vnet'
//   - Shorter, more readable syntax
//   - Native module support for large deployments
// ============================================================

// ---------- Parameters ----------

@description('Prefix for all resource names.')
@maxLength(15)
param prefix string = 'secureinsure'

@description('Deployment environment.')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region. Restricted to eastus and eastus2 by subscription policy.')
@allowed(['eastus', 'eastus2'])
param location string = 'eastus'

@description('VNet address space. Use different ranges per region to enable peering.')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Web tier subnet prefix.')
param webSubnetPrefix string = '10.1.1.0/24'

@description('App tier subnet prefix.')
param appSubnetPrefix string = '10.1.2.0/24'

@description('VM SKU. Allowed by subscription policy: B1ms/B2ms for dev, B4ms/D2_v3 for prod.')
@allowed(['Standard_B1ms', 'Standard_B2ms', 'Standard_B4ms', 'Standard_D2_v3', 'Standard_DS1_v2'])
param vmSize string = 'Standard_B2ms'

@description('Admin username for the VM.')
param adminUsername string = 'azureadmin'

@description('Admin password. Must meet Azure complexity requirements.')
@secure()
param adminPassword string

// ---------- Variables ----------

var vnetName = '${prefix}-vnet-${environment}'
var nsgWebName = 'nsg-web-${environment}'
var nsgAppName = 'nsg-app-${environment}'
var publicIpName = '${prefix}-pip-${environment}'
var nicName = '${prefix}-nic-${environment}'
var vmName = '${prefix}-vm-${environment}'
var osDiskName = '${prefix}-osdisk-${environment}'
var webSubnetName = 'snet-web'
var appSubnetName = 'snet-app'

// ---------- Resources ----------

// NSG for the Web subnet
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgWebName
  location: location
  tags: {
    environment: environment
    tier: 'web'
    project: prefix
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          description: 'Allow HTTP traffic from Internet to web tier'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS traffic from Internet to web tier'
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
          description: 'Allow Azure Load Balancer health probes'
        }
      }
      {
        name: 'Allow-SSH-Admin'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'SSH for administration. Restrict source IP in production.'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit deny all — defense in depth'
        }
      }
    ]
  }
}

// NSG for the App subnet
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgAppName
  location: location
  tags: {
    environment: environment
    tier: 'app'
    project: prefix
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-App-From-WebSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
          description: 'Allow app traffic only from web tier subnet'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'App tier must never be directly accessible from Internet'
        }
      }
      {
        name: 'Deny-All-Inbound'
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

// Virtual Network with subnets
// NOTE: Bicep automatically infers that this depends on nsgWeb and nsgApp
//       because we reference their .id properties below
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: {
    environment: environment
    project: prefix
  }
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: webSubnetName
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsgWeb.id   // Bicep resolves this dependency automatically
          }
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsgApp.id   // Bicep resolves this dependency automatically
          }
        }
      }
    ]
  }
}

// Public IP address for demo access
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpName
  location: location
  tags: {
    environment: environment
    project: prefix
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${prefix}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  tags: {
    environment: environment
    project: prefix
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id  // Web subnet
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: {
    environment: environment
    tier: 'web'
    project: prefix
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// ---------- Outputs ----------

@description('VNet resource ID — useful for peering and cross-resource references')
output vnetId string = vnet.id

@description('VNet name')
output vnetName string = vnet.name

@description('Web subnet resource ID')
output webSubnetId string = vnet.properties.subnets[0].id

@description('VM public IP address')
output vmPublicIp string = publicIp.properties.ipAddress

@description('VM FQDN for DNS access')
output vmFqdn string = publicIp.properties.dnsSettings.fqdn
