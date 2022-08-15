@description('Regions of Resource Group')
param primaryRegion string
param secondaryRegion string

@description('resource name is unique')
param solution string = 'omni${uniqueString(resourceGroup().id)}'

@description('Resource Group Names where resources will be hosted')
param eus2rgName string
param cusrgName string

@description('Vnet Name & properties in primary region ')
param eus2vnetName string
param natpipName string
param natgwName string

@description('Vnet Name & properties in secondary region')
param cusvnetName string

@description('Name of the Load Balancer')
param loadbalancerName string
param lbfrontendName string
param lbbackendpoolName string
param lbprobeName string
param lbruleName string

@description('VM Prefix Name')
param vmnamePrefix string
param adminuserName string
param adminusernamePassword string

@description('Name of Vault')
param vaultName string
param policyName string

@description('VMs to be protected')
param protectableItems array

@description('User Assigned Managed Identity that has Contributor Access to Source, Target, and resources that will be deployed')
param identity string

@description('Target Resource Group Id')
param targetResourceGroupId string


var storageaccountName = 'sa${solution}'

// Create Storage Account for cache in Eus2 Region
module eus2storageAccount 'modules/storage.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-storageaccount'
  params: {
    location: primaryRegion
    storageaccountName: '${storageaccountName}eus2'
    storageSku: 'Standard_LRS'
  }
}
output eus2storageaccount string = eus2storageAccount.outputs.storageaccountblobendpoint

// Create Storage Account for cache in CUS Region
module cusstorageAccount 'modules/storage.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-storageaccount'
  params: {
    location: secondaryRegion
    storageaccountName: '${storageaccountName}cus'
    storageSku: 'Standard_LRS'
  }
}
output cusstorageaccount string = cusstorageAccount.outputs.storageaccountblobendpoint 

// Create PublicIp for Load Balancer Outbound Connectivity for ASR replication in EUS2
module lbpipnateus2 'modules/natpip.bicep' = {
  scope: resourceGroup(eus2rgName) 
  name: 'eus2-pip'
  params: {
    natpipName: '${natpipName}-eus2'
    location: primaryRegion
  }
}

// Create PublicIp for Load Balancer Outbound Connectivity for ASR replication in CUS
module lbpipnatcus 'modules/natpip.bicep' = {
  scope: resourceGroup(cusrgName) 
  name: 'cus-pip'
  params: {
    natpipName: '${natpipName}-cus'
    location: secondaryRegion
  }
}

// Create NAT Gateway for outbound EUS2
module eus2Natgw 'modules/natgateway.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-natgw'
  params: {
    natpipName: '${natpipName}-eus2'
    natgatewayname: natgwName
    location: primaryRegion
  }
  dependsOn: [
    lbpipnateus2
  ]
}

// Create NAT Gateway for outbound CUS
module cusNatgw 'modules/natgateway.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-natgw'
  params: {
    natpipName: '${natpipName}-cus'
    natgatewayname: natgwName
    location: secondaryRegion
  }
  dependsOn: [
    lbpipnatcus
  ]
}

// Create EUS2 Vnet
module eus2vnet 'modules/vnetnatgw.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-vnet'
  params: {
    infrasubnetaddressPrefix: '10.21.0.0/24'
    infrasubnetName: 'snet-10-21-0-0_24-infra-eus2'
    paassubnetaddressPrefix: '10.21.1.0/24'
    paassubnetName: 'snet-10-21-1.0_24-paas-eus2'
    vnetaddresPrefix: '10.21.0.0/18'
    vnetName: eus2vnetName
    location: primaryRegion
    natgatewayName: natgwName
  }
  dependsOn: [
    eus2Natgw
  ]
}
output eus2vnetId string = eus2vnet.outputs.vnetId



// Create CUS Vnet
module cusvnet 'modules/vnetnatgw.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-vnet'
  params: {
    infrasubnetaddressPrefix: '10.22.0.0/24'
    infrasubnetName: 'snet-10-22-0-0_24-infra-cus'
    paassubnetaddressPrefix: '10.22.1.0/24'
    paassubnetName: 'snet-10-22-64-1_24-paas-cus'
    vnetaddresPrefix: '10.22.0.0/18'
    vnetName: cusvnetName
    location: secondaryRegion
    natgatewayName: natgwName
  }
  dependsOn: [
    cusNatgw
  ]
}
output cusvnetId string = cusvnet.outputs.vnetId


// Create Load Balancer in Primary Region (EUS2)
module eus2loadbalancer 'modules/loadBalancer.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-loadbalancer'
  params: {
    infrasubnetId: eus2vnet.outputs.infrasubnetId
    lbbackendPoolName: lbbackendpoolName
    lbfrontEndName: lbfrontendName
    lbprobeName: lbprobeName
    lbruleName: lbruleName
    loadbalancerName: loadbalancerName
    location: primaryRegion 
    privateipAddress: '10.21.0.20'
  }
  dependsOn: [
    eus2vnet
    eus2Natgw
  ]
}
output eus2loadbalancerId string = eus2loadbalancer.outputs.loadbalancerId

// Create NIC for Vms in primary region (EUS2)
module eus2vmnics 'modules/vmnic.bicep' = {
  name: 'eus2-nics'
  params: {
    nicName: 'nic'
    loadbalancerName: loadbalancerName
    location: primaryRegion
    subnetId: eus2vnet.outputs.infrasubnetId
    backendPool: lbbackendpoolName
  }
  dependsOn: [
     eus2vnet
     eus2loadbalancer
  ]
}
output vmnics array = eus2vmnics.outputs.vmnicsid


// Create Vms in primaty region (Eus2)
module eus2vms 'modules/vms-avzone.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-vms'
  params: {
    adminPassword: adminusernamePassword
    adminUsername: adminuserName
    location: primaryRegion
    storageaccountName: eus2storageAccount.outputs.storageaccountname
    vmnamePrefix: vmnamePrefix
  }
  dependsOn: [
    eus2vmnics
    eus2storageAccount
  ]
}

// Create Recovery Service Vault (not needed after creation)
module asrvault 'modules/siteRecovery.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-asrvault'
  params: {
    location: primaryRegion
    vaultName: vaultName
    policyName: policyName
    backupFabric: 'Azure'
    vmsresourceGroup: eus2rgName
    protectableItems: protectableItems
  }
  dependsOn: [
    eus2vms
  ]
}

// Rbac assignment to storage account in primary region (EUS2)
module eus2storageRbac 'modules/rbacassignment.bicep' = {
  name: 'eus2-rg-rbac'
  params: {
    principalId: asrvault.outputs.managedIdentityId
    contributorroleId: '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    resourcegroupId: '${subscription().subscriptionId}/resourceGroups/${eus2rgName}'
    resourcegroupName: eus2rgName
    storageblobdatacontributorroleId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
  dependsOn: [
    eus2storageAccount
    asrvault
  ]
}

// Rbac assignment to storage account in primary region (CUS)
module cusstorageRbac 'modules/rbacassignment.bicep' = {
  name: 'cus-rg-rbac'
  scope: resourceGroup(cusrgName)
  params: {
    principalId: asrvault.outputs.managedIdentityId
    contributorroleId: '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    resourcegroupId: '${subscription().subscriptionId}/resourceGroups/${cusrgName}'
    resourcegroupName: cusrgName
    storageblobdatacontributorroleId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
  dependsOn: [
    cusstorageAccount
    asrvault
  ]
}


// Enable Replication (EUS2)
module asrreplication 'modules/replication-avzone.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'asr-replication'
  params: {
    identity: identity
    location: primaryRegion
    primaryRegion: primaryRegion
    primaryStagingStorageAccount: eus2storageAccount.outputs.storageaccountId
    recoveryRegion: secondaryRegion
    sourceVmARMIds: eus2vms.outputs.vmIds
    targetResourceGroupId: targetResourceGroupId
    targetVirtualNetworkId: cusvnet.outputs.infrasubnetId
    vaultName: vaultName
    vaultResourceGroupName: eus2rgName
    vaultSubscriptionId: subscription().subscriptionId
  }
  dependsOn: [
    asrvault
  ]
}

