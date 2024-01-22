targetScope = 'resourceGroup'

// =====================================================

param ServerName string 

param AdminUsername string = 'godfather'

@secure()
param AdminPassword string

param WorldSeed string = ''

@allowed(['survival', 'creative', 'adventure'])
param WorldMode string = 'survival'

@allowed(['peaceful', 'easy', 'normal', 'hard'])
param WorldDifficulty string = 'easy'

// =====================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

var ResourcePrefix = 'minecraft${uniqueString(resourceGroup().id, ServerName)}'

// =====================================================

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${ResourcePrefix}-NIC'
  location: ResourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${ResourcePrefix}-NSG'
  location: ResourceLocation
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DNSSpoof'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '53'
        }
      }
      {
        name: 'BedrockTCP'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '19132'
        }
      }
      {
        name: 'BedrockUDP'
        properties: {
          priority: 1300
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '19132'
        }
      }]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${ResourcePrefix}-VNET'
  location: ResourceLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/24'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: vnet
  name: 'default'
  properties: {
    addressPrefix: '192.168.0.0/24'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${ResourcePrefix}-PIP'
  location: ResourceLocation
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: toLower(ResourcePrefix)
    }
    idleTimeoutInMinutes: 4
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: '${ResourcePrefix}-VM'
  location: ResourceLocation
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-minimal-jammy'
        sku: 'minimal-22_04-lts'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: ServerName
      adminUsername: AdminUsername
      adminPassword: AdminPassword
    }
  }
}

resource vmInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: ResourceLocation
  parent: vm
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/markusheiliger/minecraft/main/environments/bedrock/scripts/minecraft.sh'
      ]
      commandToExecute: './minecraft.sh -s ${WorldSeed} -m ${WorldMode} -d ${WorldDifficulty}'
    }

  }
}

// =====================================================

output SSHCommand string = 'ssh ${AdminUsername}@${publicIP.properties.ipAddress}'
