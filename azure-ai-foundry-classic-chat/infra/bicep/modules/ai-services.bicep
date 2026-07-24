// Azure AI Services account (kind=AIServices) — required for classic AZURE_AI_SERVICES connections.

@description('AI Services account name (globally unique custom subdomain)')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('SKU name (S0 for standard)')
param skuName string = 'S0'

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

@description('Optional model deployment on this account')
param deployModel bool = true

@description('Model deployment name (also used as model= in chat.py)')
param deploymentName string = 'gpt-5-mini'

@description('Model name')
param modelName string = 'gpt-5-mini'

@description('Model version')
param modelVersion string = '2025-08-07'

@description('Model format')
param modelFormat string = 'OpenAI'

@description('Deployment SKU (GlobalStandard | Standard | ...)')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity (TPM units for pay-go SKUs)')
@minValue(1)
param deploymentSkuCapacity int = 1

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = if (deployModel) {
  parent: aiServices
  name: deploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentSkuCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      version: modelVersion
    }
  }
}

output id string = aiServices.id
output name string = aiServices.name
output endpoint string = aiServices.properties.endpoint
output deploymentName string = deployModel ? modelDeployment.name : ''
