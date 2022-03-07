param principalId string
param appConfigName string

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2020-06-01' existing = {
  name: appConfigName
}

// Azure built-in roles: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var _roleIdAppConfigurationDataReader = '516239f1-63e1-4d78-a4de-a74fb236a071'

resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = if (!empty(appConfig.id)) {
  name: guid(subscription().id, appConfigName, principalId, _roleIdAppConfigurationDataReader)
  scope: appConfig
  properties: {
    principalId: principalId
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${_roleIdAppConfigurationDataReader}'
  }
}
