@description('Location for created resources.')
param location string = resourceGroup().location

@description('Name of the Azure Kubernetes Service to create.')
param name string

@description('Node size for the system node pool.')
param nodeVmSize string = 'Standard_B4ms'

@description('Node count in the system node pool.')
param nodeCount int = 1

@description('The maximum number of pods that can run on a node.')
param maxPods int = 60

@description('Full resource ID for log analytics workspace. If set, monitoring agent addon is enabled on AKS.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Name of the user assigned identity used for pod identities.')
param podIdentityName string = 'aks-pod-identity'

resource podIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
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

// This name is automatically generated when AKS is created.
// But we need the value before, to use it as a scope in 'nodeRsgRoleAssignment'.
var _nodeResourceGroupName = 'MC_${resourceGroup().name}_${name}_${location}'

resource aks 'Microsoft.ContainerService/managedClusters@2021-11-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: name
    nodeResourceGroup: _nodeResourceGroupName
    agentPoolProfiles: [
      {
        name: 'system'
        vmSize: nodeVmSize
        count: nodeCount
        mode: 'System' // At least one system pool is mandatory.
        maxPods: maxPods
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

module nodeRsgRoleAssignment 'rsgRoleAssignment.bicep' = {
  name: 'nodeRsgRoleAssignment'
  scope: resourceGroup(_nodeResourceGroupName)
  params: {
    principalId: podIdentity.properties.principalId
    resourceGroupName: aks.properties.nodeResourceGroup
    // Virtual Machine Contributor (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
    roleId: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
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
  id: podIdentity.id
  name: podIdentity.name
  clientId: podIdentity.properties.clientId
  principalId: podIdentity.properties.principalId
}
