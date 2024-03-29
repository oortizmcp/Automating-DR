param location string
param subnetId string
param nicName string

var numberofInstances = 2



// Create Network interfaces for VMs
resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' = [for i in range(0, numberofInstances): {
  name: '${nicName}${i}'
  location: location
  properties: {
     ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            subnet: {
              id: subnetId
            }
          }
        }
     ]
      enableAcceleratedNetworking: true
  }
}]

output vmnicsid array = [for i in range(0, numberofInstances): {
  id: networkInterface[i].id
}]
