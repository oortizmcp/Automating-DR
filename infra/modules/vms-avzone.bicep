
param adminUsername string
@secure()
param adminPassword string
param vmnamePrefix string
param location string
param vmSize string = 'Standard_D2s_v3'
param storageaccountName string
param availabilityzone array = [1, 2]



var numberofInstances = 2
var nicName = 'nic'


resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' existing = [for i in range(0, numberofInstances): {
  name: '${nicName}${i}'
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageaccountName
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberofInstances): {
  name: '${vmnamePrefix}${i}'
  location: location
  zones: ['${availabilityzone[i]}']
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmnamePrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
         {
           id: networkInterface[i].id
         }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]

output vmNames array = [for i in range(0, numberofInstances) :{
  name: vm[i].name
}]

output vmIds array = [for i in range(0, numberofInstances): {
  id: vm[i].id
}]


