param pipName string
param location string

resource pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
     publicIPAddressVersion: 'IPv4'
     publicIPAllocationMethod: 'Static'
     idleTimeoutInMinutes: 4
     dnsSettings: {
        domainNameLabel: pipName
        fqdn: '${pipName}.${location}.cloudapp.azure.com'
     }
  }
}

output pipId string = pip.id
