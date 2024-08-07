targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

// Optional parameters
param userAssignedIdentityName string = ''
param sqlServerName string = ''
param functionPlanName string = ''
param functionStorName string = ''
param functionAppName string = ''
param staticWebAppName string = ''


// *ServiceName is used as value for the tag (azd-service-name) azd uses to identify deployment host
param webServiceName string = 'web'
param apiServiceName string = 'api'

var abbreviations = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  repo: 'https://github.com/jodyford-msft/dab-azure-sql-quickstart'
}


resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name:environmentName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup
}

module storage 'app/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    storName: !empty(functionStorName) ? functionStorName : '${abbreviations.storageAccounts}${resourceToken}'
    location: location
    tags: tags
    managedIdentityClientId: identity.properties.clientId
  }
}

module web 'app/web.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    appName: !empty(staticWebAppName) ? staticWebAppName : '${abbreviations.staticWebApps}-${resourceToken}'
    location: location
    tags: tags
    serviceTag: webServiceName
    userAssignedManagedIdentity: {
      name: identity.name
      resourceId: identity.properties.principalId
      clientId: identity.properties.clientId
    }
    functionAppName: api.outputs.name
  }
}

module api 'app/api.bicep' = {
  name: 'api'
  scope: resourceGroup
  params: {
    planName: !empty(functionPlanName) ? functionPlanName : '${abbreviations.appServicePlans}-${resourceToken}'
    funcName: !empty(functionAppName) ? functionAppName : '${abbreviations.functionApps}-${resourceToken}'
    location: location
    tags: tags
    serviceTag: apiServiceName
    storageAccountName: storage.outputs.name
    userAssignedManagedIdentity: {
      resourceId: identity.properties.principalId
      clientId: identity.properties.clientId
    }
  }
}


resource existingSqlServer 'Microsoft.Sql/servers@2021-02-01-preview' existing = {
  name: sqlServerName
  scope: resourceGroup
}

// Reference the user-assigned managed identity

var existingSqlServerId = existingSqlServer.id
var identityId = identity.id

// Reference the module
module sqlServerIdentityModule 'app/mi.bicep' = {
  name: 'sqlServerIdentityModule'
  scope: resourceGroup
  params: {
    existingSqlServerId: existingSqlServerId
    identityId: identityId
    sqlServerName: sqlServerName
    identityPrincipalId: identity.properties.principalId
  }
}

// Application outputs
output AZURE_STATIC_WEB_APP_ENDPOINT string = web.outputs.endpoint
output AZURE_FUNCTION_API_ENDPOINT string = api.outputs.endpoint
output AZURE_SQL_SERVER_ENDPOINT string = existingSqlServer.properties.fullyQualifiedDomainName

