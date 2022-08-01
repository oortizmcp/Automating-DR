param storageaccountName string
param location string
param storageSku string



// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageaccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
}

output storageaccountblobendpoint string = storageAccount.properties.primaryEndpoints.blob
output storageaccountId string = storageAccount.id
output storageaccountname string = storageAccount.name
