param vaultName string
param location string
param policyName string
param vmsresourceGroup string
param backupFabric string
param protectableItems array

var v2VmContainer = 'iaasvmcontainer;iaasvmcontainerv2;'
var v2Vm = 'vm;iaasvmcontainerv2;'
var v2VmType = 'Microsoft.Compute/virtualMachines'


var scheduleRuntimes = [
  '2022-05-20T01:30:00Z'
]

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

// Create Backup Policy
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2022-02-01' =  {
  parent: recoveryVault
  name: policyName
  location: location
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 5
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunTimes: scheduleRuntimes
      scheduleRunFrequency: 'Daily'
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: scheduleRuntimes
        retentionDuration: {
          count: 104
          durationType: 'Days'
        }
      }
    weeklySchedule: {
      daysOfTheWeek: [
        'Sunday'
        'Tuesday'
        'Thursday'
      ]
      retentionTimes: scheduleRuntimes
      retentionDuration: {
        count: 104
        durationType: 'Weeks'
      }
    }
    monthlySchedule: {
      retentionScheduleFormatType: 'Daily'
      retentionScheduleDaily: {
        daysOfTheMonth: [
           {
             date: 1
             isLast: false
           }
        ]
      }
      retentionTimes: scheduleRuntimes
      retentionDuration: {
        count: 60
        durationType: 'Months'
      }
    }
    yearlySchedule: {
      retentionScheduleFormatType: 'Daily'
      monthsOfYear: [
        'January'
        'March'
        'August'
      ]
      retentionScheduleDaily: {
        daysOfTheMonth: [
           {
             date: 1
             isLast: false
           }
        ]
      }
      retentionTimes: scheduleRuntimes
      retentionDuration: {
        count: 10
        durationType: 'Years'
      }
    }
      }
      timeZone: 'UTC'
    }
}

// Protect Vms (vms that can be back up, are in the same region as vault and not protected by another vault )
resource protectedItems 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2021-03-01' = [for item in protectableItems: {
  name: '${vaultName}/${backupFabric}/${v2VmContainer}${vmsresourceGroup};${item}/${v2Vm}${vmsresourceGroup};${item}'
  location: location
  properties: {
    protectedItemType: v2VmType
    policyId: backupPolicy.id
    sourceResourceId: resourceId(subscription().subscriptionId, vmsresourceGroup, v2VmType, item)
  }
}]

output vaultprovisionState string = recoveryVault.properties.provisioningState
output vaultId string = recoveryVault.id
output backuppolicyId string = backupPolicy.id
output managedIdentityId string = recoveryVault.identity.principalId
