// Classic Foundry AI Hub (Machine Learning workspace kind=hub) + shared AIServices connection.

@description('Hub name')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('Display name')
param friendlyName string = name

@description('Hub description text')
param hubDescription string = 'Classic Foundry hub for Lesson 1'

@description('Storage account resource ID')
param storageAccountId string

@description('Key Vault resource ID')
param keyVaultId string

@description('Application Insights resource ID (optional)')
param applicationInsightsId string = ''

@description('AI Services account resource ID')
param aiServicesId string

@description('AI Services endpoint URL')
param aiServicesEndpoint string

@description('Shared connection name on the hub')
param connectionName string

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: friendlyName
    description: hubDescription
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: !empty(applicationInsightsId) ? applicationInsightsId : null
    publicNetworkAccess: 'Enabled'
  }
}

// Required by azure-ai-projects get_chat_completions_client() → ConnectionType.AZURE_AI_SERVICES
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: hub
  name: connectionName
  properties: {
    category: 'AIServices'
    target: aiServicesEndpoint
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: listKeys(aiServicesId, '2024-10-01').key1
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServicesId
      Location: location
    }
  }
}

output id string = hub.id
output name string = hub.name
output connectionName string = aiServicesConnection.name
