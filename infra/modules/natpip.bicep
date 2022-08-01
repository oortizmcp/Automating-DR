param natpipName string
param location string

resource natpip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: natpipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
     publicIPAddressVersion: 'IPv4'
     publicIPAllocationMethod: 'Static'
     idleTimeoutInMinutes: 10
  }
}

output natpipId string = natpip.id
