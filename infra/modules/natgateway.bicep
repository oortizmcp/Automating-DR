
param natpipName string
param natgatewayname string
param location string


// Existing Public Ip for Nat GW
resource natpip 'Microsoft.Network/publicIPAddresses@2021-08-01' existing = {
  name: natpipName
}

// Create Nat Gateway
resource natgateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: natgatewayname
  location: location   
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natpip.id
      }
    ]
  }
}
