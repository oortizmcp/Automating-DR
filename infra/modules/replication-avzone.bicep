param location string
@description('ARM ID of a user managed identity that has contributor access to the source, target, and the resource group where the template is being deployed.')
param identity string

@description('Subscription Id of the Recovery Services Vault.')
param vaultSubscriptionId string

@description('Name of the Recovery Services Vault to be used.')
param vaultName string

@description('Resource Group Name of the Recovery Services Vault.')
param vaultResourceGroupName string

@description('The region where the original source virtual machines are deployed.')
param primaryRegion string

@description('The designated disaster recovery region where virtual machines would be brought up after failover.')
param recoveryRegion string

@description('Name of the Replication policy to be used to create a new replication policy if protection containers are not mapped.')
param policyName string = '24-hour-replication-policy'

@description('Comma separated values of ARM IDs of the Source VMs.')
param sourceVmARMIds array

@description('ARM ID of the resource group to be used to create virtual machine in DR region.')
param targetResourceGroupId string

@description('ARM ID of the virtual network to be used by virtual machine in DR region.')
param targetVirtualNetworkId string

@description('ARM ID of the storage account to be used to cache replication data in the source region.')
param primaryStagingStorageAccount string

@description('Type of the Storage account to be used for Disk used for replication.')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
  'StandardSSD_LRS'
])
param recoveryReplicaDiskAccountType string = 'Standard_LRS'

@description('Type of the Storage account to be used for Recovery Target Disk.')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
  'StandardSSD_LRS'
])
param recoveryTargetDiskAccountType string = 'Standard_LRS'
param forceTag string = utcNow()


// Enabling Replication
resource EnableReplication 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'EnableReplication'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity}': {}
    }
  }
  properties: {
    forceUpdateTag: forceTag
    azPowerShellVersion: '7.0'
    timeout: 'PT4H'
    arguments: '-VaultSubscriptionId ${vaultSubscriptionId} -vaultResourceGroupName ${vaultResourceGroupName} -vaultName ${vaultName} -primaryRegion ${replace(string(primaryRegion), ' ', '')} -recoveryRegion ${replace(string(recoveryRegion), ' ', '')} -policyName ${policyName} -sourceVmARMIdsCSV \\"${sourceVmARMIds}\\" -TargetResourceGroupId ${targetResourceGroupId} -TargetVirtualNetworkId ${targetVirtualNetworkId} -PrimaryStagingStorageAccount ${primaryStagingStorageAccount} -RecoveryReplicaDiskAccountType ${recoveryReplicaDiskAccountType} -RecoveryTargetDiskAccountType ${recoveryTargetDiskAccountType}'
    primaryScriptUri: 'https://raw.githubusercontent.com/oortizmcp/PSScripts/master/Enable-Replication-AvZone.ps1'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}

