/**
      This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
      Copyright © Adguard Software Limited. All rights reserved.

      Adguard for iOS is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      Adguard for iOS is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
*/

import SafariAdGuardSDK
import DnsAdGuardSDK

struct ServiceInitialiser {
    let networkService: ACNNetworkingProtocol = ACNNetworking()
    let productInfo: ADProductInfoProtocol = ADProductInfo()
    
    let purchaseService: PurchaseServiceProtocol
    let safariProtection: SafariProtectionProtocol
    let complexProtection: ComplexProtectionServiceProtocol
    let dnsProvidersService: DnsProvidersServiceProtocol
    let activityStatistics: ActivityStatisticsProtocol
    
    init(resources: AESharedResourcesProtocol) {
        //MARK: - PurchaseService
        self.purchaseService = PurchaseService(network: networkService,
                                               resources: resources,
                                               productInfo: productInfo)
        //MARK: - DnsProvidersService
        self.dnsProvidersService = DnsProvidersService(resources: resources)
        
        //MARK: - SafariProtection
        let sharedStorageUrls = SharedStorageUrls()
        let safariConfiguration = Bundle.main.createSafariSDKConfig(proStatus: purchaseService.isProPurchased, resources: resources)
        self.safariProtection = try! SafariProtection(configuration: safariConfiguration,
                                                      defaultConfiguration: safariConfiguration,
                                                      filterFilesDirectoryUrl: sharedStorageUrls.filtersFolderUrl,
                                                      dbContainerUrl: sharedStorageUrls.dbFolderUrl,
                                                      jsonStorageUrl: sharedStorageUrls.cbJsonsFolderUrl,
                                                      userDefaults: resources.sharedDefaults())
        //MARK: - ComplexProtection
        let oldConfiguration = ConfigurationService(purchaseService: purchaseService, resources: resources, safariProtection: safariProtection)
        let networkSettings = NetworkSettingsService(resources: resources)
        let nativeProviders = NativeProvidersService(dnsProvidersService: dnsProvidersService, networkSettingsService: networkSettings, resources: resources, configuration: oldConfiguration)
        

        let vpnManager = VpnManager(resources: resources, configuration: oldConfiguration, networkSettings: NetworkSettingsService(resources: resources), dnsProviders: dnsProvidersService as! DnsProvidersService)
        
        self.complexProtection = ComplexProtectionService(resources: resources,
                                 configuration: oldConfiguration,
                                 vpnManager: vpnManager,
                                 productInfo: productInfo,
                                 nativeProvidersService: nativeProviders,
                                 safariProtection: safariProtection)
        
        //MARK: - ActivityStatistics
        self.activityStatistics = try! ActivityStatistics(statisticsDbContainerUrl: sharedStorageUrls.dbFolderUrl)
    }
}
