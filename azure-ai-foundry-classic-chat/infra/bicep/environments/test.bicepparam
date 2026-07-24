using '../main.bicep'

// Shared test/staging environment (same cost profile as dev)
param workloadName = 'aialearn'
param environmentName = 'test'
param location = 'eastus'
param regionShortName = 'eus'

param tags = {
  workload: 'aialearn'
  env: 'test'
  owner: 'accelerator'
  createdBy: 'bicep'
}

param deployModel = true
param deploymentName = 'gpt-5-mini'
param modelName = 'gpt-5-mini'
param modelVersion = '2025-08-07'
param deploymentSkuName = 'GlobalStandard'
param deploymentSkuCapacity = 1
param deployApplicationInsights = true
