param trafficManagerName string
param trafficManagerStatus string
param trafficRoutingMethod string
param trafficManagerProfileDnsConfigTTL int
param trafficManagerProfileMonitorConfigPath string
param trafficManagerProfileMonitorConfigPort int
param trafficManagerProfileMonitorConfigProtocol string
param trafficManagertoleratedNumberOfFailures int
param trafficManagerIntervalInSeconds int
param trafficManagerTimeoutInSeconds int
param endpoints array


// Create Traffic Manager Profile
resource trafficManagerName_resource 'Microsoft.Network/trafficManagerProfiles@2018-04-01' = {
  name: trafficManagerName
  location: 'global'
  properties: {
    endpoints: [for endpoint in endpoints: {
      name: endpoint.Name
      type: 'Microsoft.Network/trafficManagerProfiles/azureEndpoints'
      properties: {
        targetResourceId: endpoint.Id
        endpointStatus: 'Enabled'
      }
    }]
    dnsConfig: {
      relativeName: trafficManagerName
      ttl: trafficManagerProfileDnsConfigTTL
    }
    profileStatus: trafficManagerStatus
    trafficRoutingMethod: trafficRoutingMethod
    monitorConfig: {
      protocol: trafficManagerProfileMonitorConfigProtocol
      port: trafficManagerProfileMonitorConfigPort
      path: trafficManagerProfileMonitorConfigPath
      intervalInSeconds: trafficManagerIntervalInSeconds
      toleratedNumberOfFailures: trafficManagertoleratedNumberOfFailures
      timeoutInSeconds: trafficManagerTimeoutInSeconds
    }
  }
}








