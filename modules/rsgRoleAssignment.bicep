param principalId string
param resourceGroupName string
param roleId string

resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(subscription().id, resourceGroupName, principalId, roleId)
  properties: {
    principalId: principalId
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${roleId}'
  }
}
