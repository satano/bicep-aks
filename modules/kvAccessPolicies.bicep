param principalId string
param keyVaultName string

resource keyVaultAccess 'Microsoft.KeyVault/vaults/accessPolicies@2021-04-01-preview' = if (!empty(keyVaultName)) {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          keys: []
          certificates: []
          storage: []
        }
      }
    ]
  }
}
