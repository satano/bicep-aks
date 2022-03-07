@description('Location for created resources.')
param location string = resourceGroup().location

@description('Name of the Service Bus Namespace.')
param name string

@description('Names of the service bus queues to create.')
param queues array = []

@description('List of objects of the service bus topics to create. Every item must containe at least "name" property and may contain list of subscription names in "subscriptions" property.')
param topics array = []

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource sbQueues 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = [for queue in queues: {
  parent: serviceBus
  name: queue
}]

resource sbTopics 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' = [for topic in topics: {
  parent: serviceBus
  name: topic.name
}]

module topicSubscriptions 'serviceBusTopicSubscriptions.bicep' = [for (topic, i) in topics: {
  name: '${deployment().name}-subscriptions-${i}'
  params: {
    serviceBusName: serviceBus.name
    topicName: sbTopics[i].name
    subscriptionNames: topic.subscriptions
  }
}]

var _listKeysEndpoint = '${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey'
var _keys = listKeys(_listKeysEndpoint, serviceBus.apiVersion)

output serviceBus object = {
  id: serviceBus.id
  name: serviceBus.name
  serviceBusEndpoint: serviceBus.properties.serviceBusEndpoint
  primaryConnectionString: _keys.primaryConnectionString
}
