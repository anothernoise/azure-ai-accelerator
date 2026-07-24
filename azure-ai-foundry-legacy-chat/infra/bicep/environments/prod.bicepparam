using '../main.bicep'

// Production — use a dedicated subscription/RG; review capacity and model before deploy
param workloadName = 'aialearn'
param environmentName = 'prod'
param location = 'eastus'
param regionShortName = 'eus'

// Optional: pin suffix for stable global names across redeploys
// param uniqueSuffix = 'prod01'

param tags = {
  workload: 'aialearn'
  env: 'prod'
  owner: 'accelerator'
  createdBy: 'bicep'
  criticality: 'production'
}

param deployModel = true
param deploymentName = 'gpt-5-mini'
param modelName = 'gpt-5-mini'
param modelVersion = '2025-08-07'
param deploymentSkuName = 'GlobalStandard'
// Increase only after quota/cost review
param deploymentSkuCapacity = 1
param deployApplicationInsights = true
