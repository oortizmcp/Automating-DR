param vnetName string
param location string
param vnetaddresPrefix string
param infrasubnetName string
param infrasubnetaddressPrefix string
param paassubnetName string
param paassubnetaddressPrefix string
param appgwsubnetName string
param appgwsubnetaddressPrefix string
param natgatewayName string
param nsgId string

resource natgateway 'Microsoft.Network/natGateways@2021-05-01' existing = {
  name: natgatewayName
}

// Create Vnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: vnetName
  location: location
  properties: {
     addressSpace: {
        addressPrefixes: [
          vnetaddresPrefix
        ]
     } 
      subnets: [
       {
         name: infrasubnetName
         properties: {
          addressPrefix: infrasubnetaddressPrefix
          natGateway: {
            id: natgateway.id
          }
          networkSecurityGroup: {
            id: nsgId
          }
         }
       }
       {
         name: paassubnetName
         properties: {
            addressPrefix: paassubnetaddressPrefix
            serviceEndpoints: [
              {
                 locations: [
                   location
                 ]
                 service: 'Microsoft.Sql'
              }
              {
                service: 'Microsoft.Storage'
              }
           ]
         }
       }
       {
        name: appgwsubnetName
        properties: {
          addressPrefix: appgwsubnetaddressPrefix
        }

       }
      ]
  }
}


output vnetId string = vnet.id
output infrasubnetId string = vnet.properties.subnets[0].id
output paassubnetId string = vnet.properties.subnets[1].id
output appgwsubnetId string = vnet.properties.subnets[2].id
output vnetProperties object = vnet.properties
