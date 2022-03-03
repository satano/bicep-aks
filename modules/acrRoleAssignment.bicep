param principalId string
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

// Azure built-in roles: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var roleIdAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = if (!empty(acr.id)) {
  name: guid(subscription().id, acrName, principalId, roleIdAcrPull)
  scope: acr
  properties: {
    principalId: principalId
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${roleIdAcrPull}'
  }
}
