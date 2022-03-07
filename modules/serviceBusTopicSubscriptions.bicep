@description('Name of the Service Bus Namespace.')
param serviceBusName string

@description('Name of the topic for which the subscriptions will be created.')
param topicName string

@description('Names of the subscriptions.')
param subscriptionNames array = []

resource subscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-06-01-preview' = [for subscriptioNames in subscriptionNames: {
  name: '${serviceBusName}/${topicName}/${subscriptioNames}'
}]
