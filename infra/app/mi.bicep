param existingSqlServerId string
param identityId string
param identityPrincipalId string
param sqlServerName string

resource existingSqlServer 'Microsoft.Sql/servers@2021-02-01-preview' existing = {
  name: sqlServerName
}

resource sqlServerIdentity 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(existingSqlServerId, identityId, 'db-reader')
  scope: existingSqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db-reader')
    principalId: identityPrincipalId
  }
}
