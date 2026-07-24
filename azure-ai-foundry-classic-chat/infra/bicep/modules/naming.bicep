// Shared Azure CAF-style naming for Lesson 1 classic Foundry infra.
// Abbreviations: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

@description('Short workload / application name (letters/numbers, no spaces)')
@minLength(2)
@maxLength(10)
param workloadName string

@description('Environment: dev | test | prod')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string

@description('Azure region short code used in names (e.g. eus, wus2)')
param regionShortName string

@description('Unique suffix to avoid global name collisions (storage / AI Services subdomain)')
@minLength(3)
@maxLength(6)
param uniqueSuffix string

var wl = toLower(workloadName)
var env = toLower(environmentName)
var reg = toLower(regionShortName)
var suf = toLower(uniqueSuffix)

// rg-aialearn-dev-eus
output resourceGroupName string = 'rg-${wl}-${env}-${reg}'

// ais-aialearn-dev-eus-abc12  (custom subdomain / account name: 2-64, alphanumeric + hyphen)
output aiServicesName string = 'ais-${wl}-${env}-${reg}-${suf}'

// aih-aialearn-dev-eus
output hubName string = 'aih-${wl}-${env}-${reg}'

// proj-aialearn-dev-eus
output projectName string = 'proj-${wl}-${env}-${reg}'

// Storage: 3-24 chars, lowercase alphanumeric only
output storageAccountName string = take('st${wl}${env}${suf}', 24)

// Key Vault: 3-24, alphanumeric + hyphen
output keyVaultName string = take('kv-${wl}-${env}-${suf}', 24)

// App Insights
output applicationInsightsName string = 'appi-${wl}-${env}-${reg}'

// Shared hub connection consumed by classic AIProjectClient
output aiServicesConnectionName string = 'conn-ais-${wl}-${env}'
