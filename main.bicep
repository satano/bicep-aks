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

@description('Name of the Azure Container Registry which will be connected to AKS. This means, that AKS agent pool will have AcrPull role to this registry. If this name is set, at least \'acrResourceGroupName\' must be set too.')
param acrName string = ''

@description('Resource group name where connected ACR \'acrName\' is.')
param acrResourceGroupName string = ''

@description('Subscription ID where connected ACR \'acrName\' is. If not set, current subscription will be used.')
param acrSubscriptionId string = ''

// Monitoring addon for AKS.
var _aksAddonOmsAgent = empty(logAnalyticsWorkspaceResourceId) ? {} : {
  omsagent: {
    enabled: true
    config: {
      logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceId
    }
  }
}
var _aksAddonProfiles = union({}, _aksAddonOmsAgent)

resource aks 'Microsoft.ContainerService/managedClusters@2021-11-01-preview' = {
  name: aksName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksName
    agentPoolProfiles: [
      {
        name: 'system'
        vmSize: aksNodeVmSize
        count: aksNodeCount
        mode: 'System' // At least one system pool is mandatory.
      }
    ]
    addonProfiles: _aksAddonProfiles
  }
}

var _aksObjectId = reference(aks.name).identityProfile.kubeletidentity.objectId
var _acrSubscriptionId = empty(acrSubscriptionId) ? subscription().subscriptionId : acrSubscriptionId

module acrRoleAssignment 'modules/acrRoleAssignment.bicep' = if (!empty(acrName)) {
  name: 'acrRoleAssignment'
  scope: resourceGroup(_acrSubscriptionId, acrResourceGroupName)
  params: {
    aksObjectId: _aksObjectId
    acrName: acrName
  }
}
