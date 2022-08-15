param vnetName string
param location string
param vnetaddresPrefix string
param infrasubnetName string
param infrasubnetaddressPrefix string
param paassubnetName string
param paassubnetaddressPrefix string


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
      ]
  }
}


output vnetId string = vnet.id
output infrasubnetId string = vnet.properties.subnets[0].id
output paassubnetId string = vnet.properties.subnets[1].id
output vnetProperties object = vnet.properties
