param loadbalancerName string
param location string
param infrasubnetId string
param lbfrontEndName string
param lbbackendPoolName string
param privateipAddress string
param lbprobeName string
param lbruleName string


resource loadBalancer 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: loadbalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
       {
         properties: {
           subnet: {
             id: infrasubnetId
           }
           privateIPAddress: privateipAddress
           privateIPAllocationMethod: 'Static'
         }
         name: lbfrontEndName
       }
    ]
    backendAddressPools: [
       {
         name: lbbackendPoolName
       }
    ]
    loadBalancingRules: [
       {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadbalancerName, lbfrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadbalancerName, lbbackendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadbalancerName, lbprobeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
         }
         name: lbruleName
       }
    ]
    probes: [
       {
         properties: {
           protocol: 'Tcp'
           port: 80
           intervalInSeconds: 15
           numberOfProbes: 2
         }
         name: lbprobeName
       }
    ]
  }
}


output loadbalancerId string = loadBalancer.id
output loadbalancerPrivateIp string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
