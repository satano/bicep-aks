@description('Location for created resources.')
param location string = resourceGroup().location

@description('Settings of the Azure Kubernetes Service to create.')
param aks object

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

@description('Service Bus Namespace parameters. Required property is "name", optional properties are "queues" and "topics".')
param serviceBus object

module aksCluster 'modules/aks.bicep' = {
  name: '${deployment().name}-aks'
  params: {
    location: location
    name: aks.name
    nodeVmSize: aks.nodeVmSize
    nodeCount: aks.nodeCount
    maxPods: aks.maxPods
    podIdentityName: aks.podIdentityName
    logAnalyticsWorkspaceResourceId: aks.logAnalyticsWorkspaceResourceId
  }
}

var _acrSubscriptionId = empty(acr.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : acr.subscriptionId
var _acrResourceGroupName = empty(acr.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : acr.resourceGroupName
module acrRoleAssignment 'modules/acrRoleAssignment.bicep' = if (!empty(acr.name)) {
  name: '${deployment().name}-acrRoleAssignment'
  scope: resourceGroup(_acrSubscriptionId, _acrResourceGroupName)
  params: {
    principalId: aksCluster.outputs.aks.kubeletIdentity.objectId
    acrName: acr.name
  }
}

var _appConfigSubscriptionId = empty(appConfig.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : appConfig.subscriptionId
var _appConfigResourceGroupName = empty(appConfig.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : appConfig.resourceGroupName
module appConfigRoleAssignment 'modules/appConfigRoleAssignment.bicep' = if (!empty(appConfig.name)) {
  name: '${deployment().name}-appConfigRoleAssignment'
  scope: resourceGroup(_appConfigSubscriptionId, _appConfigResourceGroupName)
  params: {
    principalId: aksCluster.outputs.podIdentity.principalId
    appConfigName: appConfig.name
  }
}

var _kvSubscriptionId = empty(keyVault.subscriptionId) ? empty(defaultSubscriptionId) ? subscription().subscriptionId : defaultSubscriptionId : keyVault.subscriptionId
var _kvResourceGroupName = empty(keyVault.resourceGroupName) ? empty(defaultResourceGroupName) ? resourceGroup().name : defaultResourceGroupName : keyVault.resourceGroupName
module kvAccessPolicies 'modules/kvAccessPolicies.bicep' = if (!empty(keyVault.name)) {
  name: '${deployment().name}-kvAccessPolicies'
  scope: resourceGroup(_kvSubscriptionId, _kvResourceGroupName)
  params: {
    principalId: aksCluster.outputs.podIdentity.principalId
    keyVaultName: keyVault.name
  }
}

module serviceBusNamespace 'modules/serviceBus.bicep' = {
  name: '${deployment().name}-serviceBus'
  params: {
    name: serviceBus.name
    location: location
    queues: serviceBus.queues
    topics: serviceBus.topics
  }
}

output aks object = aksCluster.outputs.aks
output aksPodIdentity object = aksCluster.outputs.podIdentity
output serviceBus object = serviceBusNamespace.outputs.serviceBus
