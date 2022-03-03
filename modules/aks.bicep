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

resource aksPodIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: podIdentityName
  location: location
}

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
    networkProfile: {
      networkPlugin: 'azure'
    }
    podIdentityProfile: {
      enabled: true
      allowNetworkPluginKubenet: false
    }
  }
}

output aks object = {
  id: aks.id
  name: aks.name
  principalId: aks.identity.principalId
  kubeletIdentity: {
    clientId: aks.properties.identityProfile.kubeletidentity.clientId
    objectId: aks.properties.identityProfile.kubeletidentity.objectId
    resourceId: aks.properties.identityProfile.kubeletidentity.resourceId
  }
  nodeResourceGroup: aks.properties.nodeResourceGroup
}

output podIdentity object = {
  id: aksPodIdentity.id
  name: aksPodIdentity.name
  clientId: aksPodIdentity.properties.clientId
  principalId: aksPodIdentity.properties.principalId
  tenantId: aksPodIdentity.properties.tenantId
}
