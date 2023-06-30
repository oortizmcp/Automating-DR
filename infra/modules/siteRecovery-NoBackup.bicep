param vaultName string
param location string

// Create Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2022-02-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'    
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
  }
}



output vaultprovisionState string = recoveryVault.properties.provisioningState
output vaultId string = recoveryVault.id
output managedIdentityId string = recoveryVault.identity.principalId
