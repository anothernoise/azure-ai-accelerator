// Classic Foundry hub project (Machine Learning workspace kind=Project).

@description('Project name')
param name string

@description('Azure region (must match hub)')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {}

@description('Display name')
param friendlyName string = name

@description('Parent hub resource ID')
param hubResourceId string

resource project 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: friendlyName
    description: 'Classic Foundry hub project for Lesson 1'
    hubResourceId: hubResourceId
    publicNetworkAccess: 'Enabled'
  }
}

output id string = project.id
output name string = project.name
output discoveryUrl string = project.properties.discoveryUrl
