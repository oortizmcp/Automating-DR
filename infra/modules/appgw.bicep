param appgwName string
param location string
param gatewayIpConfigName string
param appgwSubnetId string
param appgatewaybackendpoolName string
param vmip1 string
param vmip2 string
param appgwpipid string
param appgwbackendhttpsettingsName string


// Create App Gateway
resource appgw 'Microsoft.Network/applicationGateways@2022-11-01' ={
  name: appgwName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    gatewayIPConfigurations: [
      {
        name: gatewayIpConfigName
        properties: {
          subnet: {
            id: appgwSubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: appgatewaybackendpoolName
        properties:{
          backendAddresses:[
            {
              ipAddress: vmip1
            }
            {
              ipAddress: vmip2
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: appgwbackendhttpsettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    frontendPorts:[
      {
        name: 'frontendport01'
        properties: {
          port: 80
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendip01'
        properties: {
          publicIPAddress: {
            id: appgwpipid
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener01'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwName, 'frontendip01')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'frontendport01')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'requestRoutingRule01'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwName, 'httpListener01')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwName, appgatewaybackendpoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, appgwbackendhttpsettingsName)
          }
          priority: 1
        }
      }
    ]
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2
    }
  }
}

output appgwId string = appgw.id
