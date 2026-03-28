// Bicep parameter file for DR (Disaster Recovery) deployment in East US 2
// Usage: az deployment group create --template-file main.bicep --parameters main.dr.bicepparam
//
// NOTE: Uses prod-tier VM size and a non-overlapping address space (10.2.x.x)
//       so that VNet peering with the primary (10.1.x.x) can be established.

using './main.bicep'

param prefix = 'secureinsure'
param environment = 'prod'
param location = 'eastus2'
param vnetAddressPrefix = '10.2.0.0/16'
param webSubnetPrefix = '10.2.1.0/24'
param appSubnetPrefix = '10.2.2.0/24'
param vmSize = 'Standard_D2_v3'
param adminUsername = 'azureadmin'
param adminPassword = 'P@ssw0rd2024!DR'
