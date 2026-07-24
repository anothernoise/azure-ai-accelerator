// Classic Foundry hub stack for Lesson 1
// Creates: AIServices (+ model), storage, key vault, hub, AIServices connection, hub project
//
// Deploy (from repo root):
//   ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh --env dev
//   ENVIRONMENT=prod ./azure-ai-foundry-classic-chat/infra/scripts/deploy.sh

targetScope = 'resourceGroup'

@description('Short workload name used in CAF-style resource names')
@minLength(2)
@maxLength(10)
param workloadName string = 'aialearn'

@description('Environment name')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Short region code for names (eus, wus2, ...)')
param regionShortName string = 'eus'

@description('Unique suffix to avoid global name collisions')
@minLength(3)
@maxLength(6)
param uniqueSuffix string = take(uniqueString(resourceGroup().id), 5)

@description('Common tags applied to resources')
param tags object = {
  workload: workloadName
  env: environmentName
  owner: 'accelerator'
  createdBy: 'bicep'
}

@description('Deploy gpt model on AI Services account')
param deployModel bool = true

@description('Model deployment name / chat.py model=')
param deploymentName string = 'gpt-5-mini'

@description('Model name')
param modelName string = 'gpt-5-mini'

@description('Model version')
param modelVersion string = '2025-08-07'

@description('Deployment SKU')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity')
param deploymentSkuCapacity int = 1

@description('Create Application Insights for the hub')
param deployApplicationInsights bool = true

module naming 'modules/naming.bicep' = {
  name: 'naming'
  params: {
    workloadName: workloadName
    environmentName: environmentName
    regionShortName: regionShortName
    uniqueSuffix: uniqueSuffix
  }
}

module dependencies 'modules/dependencies.bicep' = {
  name: 'dependencies'
  params: {
    location: location
    tags: tags
    storageAccountName: naming.outputs.storageAccountName
    keyVaultName: naming.outputs.keyVaultName
    applicationInsightsName: naming.outputs.applicationInsightsName
    deployApplicationInsights: deployApplicationInsights
  }
}

module aiServices 'modules/ai-services.bicep' = {
  name: 'ai-services'
  params: {
    name: naming.outputs.aiServicesName
    location: location
    tags: tags
    deployModel: deployModel
    deploymentName: deploymentName
    modelName: modelName
    modelVersion: modelVersion
    deploymentSkuName: deploymentSkuName
    deploymentSkuCapacity: deploymentSkuCapacity
  }
}

module hub 'modules/ai-hub.bicep' = {
  name: 'ai-hub'
  params: {
    name: naming.outputs.hubName
    location: location
    tags: tags
    storageAccountId: dependencies.outputs.storageAccountId
    keyVaultId: dependencies.outputs.keyVaultId
    applicationInsightsId: dependencies.outputs.applicationInsightsId
    aiServicesId: aiServices.outputs.id
    aiServicesEndpoint: aiServices.outputs.endpoint
    connectionName: naming.outputs.aiServicesConnectionName
  }
}

module project 'modules/ai-project.bicep' = {
  name: 'ai-project'
  params: {
    name: naming.outputs.projectName
    location: location
    tags: tags
    hubResourceId: hub.outputs.id
  }
}

// Classic hub project connection string for azure-ai-projects==1.0.0b10
var projectConnectionString = '${location}.api.azureml.ms;${subscription().subscriptionId};${resourceGroup().name};${project.outputs.name}'

output environmentName string = environmentName
output resourceGroupName string = resourceGroup().name
output location string = location
output aiServicesName string = aiServices.outputs.name
output aiServicesEndpoint string = aiServices.outputs.endpoint
output hubName string = hub.outputs.name
output projectName string = project.outputs.name
output aiServicesConnectionName string = hub.outputs.connectionName
output deploymentName string = aiServices.outputs.deploymentName
output projectConnectionString string = projectConnectionString
output discoveryUrl string = project.outputs.discoveryUrl
