@description('Location for created resources.')
param location string = resourceGroup().location

@description('Name of the Azure Kubernetes Service to create.')
param aksName string

@description('Node size for the system node pool.')
param aksNodeVmSize string = 'Standard_B4ms'

@description('Node count in the system node pool.')
param aksNodeCount int = 1

@description('Full resource ID for log analytics workspace. If set, monitoring agent addon is enabled on AKS.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Name of the user assigned identity used for pod identities.')
param podIdentityName string = 'aks-pod-identity'

@description('Default resource group for other "external" resources, if not specified with the resource itself.')
param defaultResourceGroupName string = ''

@description('Default subscription ID for other "external" resources, if not specified with the resource itself.')
param defaultSubscriptionId string = ''

@description('Azure Container Registry which will be connected to AKS. This means, that AKS agent pool will have AcrPull role in this registry. If resource group or subscription is not set, default ones will be used.')
param acr object = {
  name: ''
  resourceGroupName: ''
  subscriptionId: ''
}

@description('App Configuration to which pod managed identity will have access with "App Configuration Data Reader" role. If resource group or subscription is not set, default ones will be used.')
param appConfig object = {
  name: ''
  resourceGroupName: ''
  subscriptionId: ''
}

@description('Key vault to which pod managed identity will have access. If resource group or subscription is not set, default ones will be used.')
param keyVault object = {
  name: ''
  resourceGroupName: ''
  subscriptionId: ''
}

module aks 'modules/aks.bicep' = {
  name: 'aks'
  params: {
    location: location
    aksName: aksName
    aksNodeVmSize: aksNodeVmSize
    aksNodeCount: aksNodeCount
    podIdentityName: podIdentityName
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
  }
}

var _acrSubscriptionId = empty(acr.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : acr.subscriptionId
var _acrResourceGroupName = empty(acr.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : acr.resourceGroupName
module acrRoleAssignment 'modules/acrRoleAssignment.bicep' = if (!empty(acr.name)) {
  name: 'acrRoleAssignment'
  scope: resourceGroup(_acrSubscriptionId, _acrResourceGroupName)
  params: {
    principalId: aks.outputs.aks.kubeletIdentity.objectId
    acrName: acr.name
  }
}

var _appConfigSubscriptionId = empty(appConfig.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : appConfig.subscriptionId
var _appConfigResourceGroupName = empty(appConfig.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : appConfig.resourceGroupName
module appConfigRoleAssignment 'modules/appConfigRoleAssignment.bicep' = if (!empty(appConfig.name)) {
  name: 'appConfigRoleAssignment'
  scope: resourceGroup(_appConfigSubscriptionId, _appConfigResourceGroupName)
  params: {
    principalId: aks.outputs.podIdentity.principalId
    appConfigName: appConfig.name
  }
}

var _kvSubscriptionId = empty(keyVault.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : keyVault.subscriptionId
var _kvResourceGroupName = empty(keyVault.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : keyVault.resourceGroupName
module kvAccessPolicies 'modules/kvAccessPolicies.bicep' = if (!empty(keyVault.name)) {
  name: 'kvAccessPolicies'
  scope: resourceGroup(_kvSubscriptionId, _kvResourceGroupName)
  params: {
    principalId: aks.outputs.podIdentity.principalId
    keyVaultName: keyVault.name
  }
}

output aks object = aks.outputs.aks
output aksPodIdentity object = aks.outputs.podIdentity
