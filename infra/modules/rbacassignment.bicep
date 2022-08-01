@description('resource group name')
param resourcegroupId string
param resourcegroupName string


@description('PrincipalId of the azure resource')
param principalId string


@description('The principal type of the assigned principal ID.')
param principalType string = 'ServicePrincipal'

@description('Role Definition ResourceId')
param contributorroleId string
param storageblobdatacontributorroleId string


// Existing resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: resourcegroupName
}


// Create RBAC for granting vault managed identity with Storage contributor role 
resource resourcegroupName_Microsoft_Authorization_rbacResourceName1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourcegroupId, principalId, contributorroleId)
  properties: {
    roleDefinitionId: contributorroleId
    principalId: principalId
    principalType: principalType
  }
}

// Create RBAC for granting vault managed identity with Storage Blob Data Contributor Roles
resource storageAccountName_Microsoft_Authorization_rbacResourceName2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourcegroupId, principalId, storageblobdatacontributorroleId)
  properties: {
    roleDefinitionId: storageblobdatacontributorroleId
    principalId: principalId
    principalType: principalType
  }
}
