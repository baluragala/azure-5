// Bicep parameter file for dev deployment
// Usage: az deployment group create --template-file main.bicep --parameters main.bicepparam

using './main.bicep'

param prefix = 'secureinsure'
param environment = 'dev'
param location = 'eastus'
param vnetAddressPrefix = '10.1.0.0/16'
param webSubnetPrefix = '10.1.1.0/24'
param appSubnetPrefix = '10.1.2.0/24'
param vmSize = 'Standard_B1ms'
param adminUsername = 'azureadmin'
param adminPassword = 'P@ssw0rd2024!Dev'
