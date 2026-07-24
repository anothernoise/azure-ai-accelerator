// Minimal dependent resources for a classic Foundry hub (learning / public access).
// Storage + Key Vault only — ACR omitted to keep free-trial cost low.

@description('Azure region')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('Storage account name (3-24 lowercase alphanumeric)')
param storageAccountName string

@description('Key Vault name')
param keyVaultName string

@description('Application Insights name (optional but commonly attached to hubs)')
param applicationInsightsName string

@description('Create Application Insights')
param deployApplicationInsights bool = true

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // learning: public; tighten for prod
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (deployApplicationInsights) {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    ImmediatePurgeDataOn30Days: true
  }
}

output storageAccountId string = storage.id
output keyVaultId string = keyVault.id
output applicationInsightsId string = deployApplicationInsights ? appInsights.id : ''
