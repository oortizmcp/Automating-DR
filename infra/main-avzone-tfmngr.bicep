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

@description('Name of the Application Gateway')
param appgatewayName string

@description('VM Prefix Name')
param vmnamePrefix string
param adminuserName string

@secure()
param adminusernamePassword string

@description('Name of Vault')
param vaultName string

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

// Create NSG in EUS2 Region
module eus2nsg 'modules/nsg.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-nsg'
  params:{
    nsgName: 'nsg-eus2'
    location: primaryRegion
    securityruleName: 'AllowHTTPInbound'
  }
}
output eus2nsgId string = eus2nsg.outputs.nsgId

// Create NSG in CUS Region
module cusnsg 'modules/nsg.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-nsg'
  params:{
    nsgName: 'nsg-cus'
    location: secondaryRegion
    securityruleName: 'AllowHTTPInbound'
  }
}
output cusnsgId string = cusnsg.outputs.nsgId

// Create PublicIp for Outbound Connectivity for ASR replication in EUS2
module lbpipnateus2 'modules/natpip.bicep' = {
  scope: resourceGroup(eus2rgName) 
  name: 'eus2-pip'
  params: {
    natpipName: '${natpipName}-eus2'
    location: primaryRegion
  }
}

// Create PublicIp for Outbound Connectivity for ASR replication in CUS
module lbpipnatcus 'modules/natpip.bicep' = {
  scope: resourceGroup(cusrgName) 
  name: 'cus-pip'
  params: {
    natpipName: '${natpipName}-cus'
    location: secondaryRegion
  }
}

// Create Public Ip for App Gateway in Primary Region (EUS2)
module eus2appgwpip 'modules/appgwpip.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-appgwpip'
  params:{
    pipName: 'pip-${appgatewayName}-eus2'
    location: primaryRegion
  }
}
output eus2appgwpip string = eus2appgwpip.outputs.pipId

// Create Public IP for App Gateway in Secondary Region (CUS)
module cusappgwpip 'modules/appgwpip.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-appgwpip'
  params:{
    pipName: 'pip-${appgatewayName}-cus'
    location: secondaryRegion
  }
}
output cusappgwpip string = cusappgwpip.outputs.pipId

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
module eus2vnet 'modules/vnetnsg.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-vnet'
  params: {
    infrasubnetaddressPrefix: '10.21.0.0/24'
    infrasubnetName: 'snet-10-21-0-0_24-infra-eus2'
    paassubnetaddressPrefix: '10.21.1.0/24'
    paassubnetName: 'snet-10-21-1.0_24-paas-eus2'
    appgwsubnetName: 'snet-10-21-2.0_24-appgw-eus2'
    appgwsubnetaddressPrefix: '10.21.2.0/24'
    vnetaddresPrefix: '10.21.0.0/18'
    vnetName: eus2vnetName
    location: primaryRegion
    natgatewayName: natgwName
    nsgId: eus2nsg.outputs.nsgId
  }
  dependsOn: [
    eus2Natgw
    eus2nsg
  ]
}
output eus2vnetId string = eus2vnet.outputs.vnetId


// Create CUS Vnet
module cusvnet 'modules/vnetnsg.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-vnet'
  params: {
    infrasubnetaddressPrefix: '10.22.0.0/24'
    infrasubnetName: 'snet-10-22-0-0_24-infra-cus'
    paassubnetaddressPrefix: '10.22.1.0/24'
    paassubnetName: 'snet-10-22-64-1_24-paas-cus'
    appgwsubnetName: 'snet-10-22-2.0_24-appgw-eus2'
    appgwsubnetaddressPrefix: '10.22.2.0/24'
    vnetaddresPrefix: '10.22.0.0/18'
    vnetName: cusvnetName
    location: secondaryRegion
    natgatewayName: natgwName
    nsgId: cusnsg.outputs.nsgId
  }
  dependsOn: [
    cusNatgw
    cusnsg
  ]
}
output cusvnetId string = cusvnet.outputs.vnetId


// Create Application Gateway in Primary Region (EUS2)
module eus2appgw 'modules/appgw.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'eus2-appgw'
  params: {
    appgatewaybackendpoolName: 'appgw-backendpool01'
    appgwbackendhttpsettingsName: 'appgw-poolsettings01'
    appgwName: '${appgatewayName}-eus2'
    appgwpipid: eus2appgwpip.outputs.pipId
    appgwSubnetId: eus2vnet.outputs.appgwsubnetId
    gatewayIpConfigName: 'gwIP01'
    vmip1: '10.21.0.4'
    vmip2: '10.21.0.5'
    location: primaryRegion
  }
  dependsOn:[
    eus2appgwpip
  ]
}
output eus2appgwId string = eus2appgw.outputs.appgwId

// Create Application Gateway in Secondary Region (CUS)
module cusappgw 'modules/appgw.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-appgw'
  params: {
    appgatewaybackendpoolName: 'appgw-backendpool01'
    appgwbackendhttpsettingsName: 'appgw-poolsettings01'
    appgwName: '${appgatewayName}-cus'
    appgwpipid: cusappgwpip.outputs.pipId
    appgwSubnetId: cusvnet.outputs.appgwsubnetId
    gatewayIpConfigName: 'gwIP01'
    vmip1: '10.22.0.4'
    vmip2: '10.22.0.5'
    location: secondaryRegion
  }
  dependsOn:[
    cusappgwpip
  ]
}
output cusappgwId string = cusappgw.outputs.appgwId

// Create Traffic Manager Profile
module tmgrprofile 'modules/trafficmngr.bicep' = {
  scope: resourceGroup(eus2rgName)
  name: 'tmgr-profile'
  params: {
    trafficManagerName: 'tmp-${appgatewayName}-eus2'
    trafficManagerStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    trafficManagerProfileDnsConfigTTL: 30
    trafficManagerProfileMonitorConfigPath: '/'
    trafficManagerProfileMonitorConfigPort: 80
    trafficManagerProfileMonitorConfigProtocol: 'HTTP'
    trafficManagertoleratedNumberOfFailures: 3
    trafficManagerIntervalInSeconds: 10
    trafficManagerTimeoutInSeconds: 7
    endpoints:[
      {
        Name: eus2appgwpip.name
        Id: eus2appgwpip.outputs.pipId
      }
      {
        Name: cusappgwpip.name
        Id: cusappgwpip.outputs.pipId
      }
    ]
  }
  dependsOn: [
    eus2appgwpip
    cusappgwpip
  ]
}

// Create NIC for Vms in primary region (EUS2)
module eus2vmnics 'modules/vmnic.bicep' = {
  name: 'eus2-nics'
  params: {
    nicName: 'nic'
    location: primaryRegion
    subnetId: eus2vnet.outputs.infrasubnetId
  }
  dependsOn: [
     eus2vnet
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

// Create Recovery Service Vault (CUS)
module asrvault 'modules/siteRecovery-NoBackup.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'cus-asrvault'
  params: {
    location: secondaryRegion
    vaultName: vaultName
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

// Enable Replication for VMS (EUS2)
module asrreplication 'modules/replication-avzone.bicep' = {
  scope: resourceGroup(cusrgName)
  name: 'asr-replication'
  params: {
    identity: identity
    location: secondaryRegion
    primaryRegion: primaryRegion
    primaryStagingStorageAccount: eus2storageAccount.outputs.storageaccountId
    recoveryRegion: secondaryRegion
    sourceVmARMIds: eus2vms.outputs.vmIds
    targetResourceGroupId: targetResourceGroupId
    targetVirtualNetworkId: cusvnet.outputs.infrasubnetId
    vaultName: vaultName
    vaultResourceGroupName: cusrgName
    vaultSubscriptionId: subscription().subscriptionId
  }
  dependsOn: [
    asrvault
  ]
}

