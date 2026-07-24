using 'main.bicep'

// Deprecated: use environments/dev.bicepparam (deploy.sh selects by ENVIRONMENT)
param workloadName = 'aialearn'
param environmentName = 'dev'
param location = 'eastus'
param regionShortName = 'eus'

param tags = {
  workload: 'aialearn'
  env: 'dev'
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
