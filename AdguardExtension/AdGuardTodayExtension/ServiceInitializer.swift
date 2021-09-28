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

protocol ServiceInitializerProtocol  {
    var networkService: ACNNetworkingProtocol { get }
    var productInfo: ADProductInfoProtocol { get }

    var purchaseService: PurchaseServiceProtocol { get }
    var safariProtection: SafariProtectionProtocol { get }
    var complexProtection: ComplexProtectionServiceProtocol { get }
    var dnsProvidersManager: DnsProvidersManagerProtocol { get }
    var activityStatistics: ActivityStatisticsProtocol { get }
}

final class ServiceInitializer: ServiceInitializerProtocol {
    let networkService: ACNNetworkingProtocol = ACNNetworking()
    let productInfo: ADProductInfoProtocol = ADProductInfo()

    let purchaseService: PurchaseServiceProtocol
    let safariProtection: SafariProtectionProtocol
    let complexProtection: ComplexProtectionServiceProtocol
    let dnsProvidersManager: DnsProvidersManagerProtocol
    let activityStatistics: ActivityStatisticsProtocol

    init(resources: AESharedResourcesProtocol) throws {
        self.purchaseService = PurchaseService(network: networkService,
                                               resources: resources,
                                               productInfo: productInfo)

        let sharedStorageUrls = SharedStorageUrls()

        let safariConfiguration = SafariConfiguration(resources: resources, isProPurchased: purchaseService.isProPurchased)

        self.safariProtection = try SafariProtection(configuration: safariConfiguration,
                                                      defaultConfiguration: safariConfiguration,
                                                      filterFilesDirectoryUrl: sharedStorageUrls.filtersFolderUrl,
                                                      dbContainerUrl: sharedStorageUrls.dbFolderUrl,
                                                      jsonStorageUrl: sharedStorageUrls.cbJsonsFolderUrl,
                                                      userDefaults: resources.sharedDefaults())

        let oldConfiguration = ConfigurationService(purchaseService: purchaseService, resources: resources, safariProtection: safariProtection)

        let networkSettings = NetworkSettingsService(resources: resources)

        let configuration = ConfigurationService(purchaseService: purchaseService, resources: resources, safariProtection: safariProtection)

        let dnsConfiguration = DnsConfiguration(resources: resources, isProPurchased: purchaseService.isProPurchased)
        self.dnsProvidersManager = try DnsProvidersManager(configuration: dnsConfiguration, userDefaults: resources.sharedDefaults())

        let nativeDnsSettingsManager = NativeDnsSettingsManager(networkSettingsService: networkSettings, dnsProvidersManager: dnsProvidersManager, configuration: configuration, resources: resources)

        let vpnManager = VpnManager(resources: resources, configuration: oldConfiguration, networkSettings: NetworkSettingsService(resources: resources))

        self.complexProtection = ComplexProtectionService(resources: resources,
                                 configuration: oldConfiguration,
                                 vpnManager: vpnManager,
                                 productInfo: productInfo,
                                 nativeDnsSettingsManager: nativeDnsSettingsManager,
                                 safariProtection: safariProtection)

        // MARK: - ActivityStatistics

        self.activityStatistics = try ActivityStatistics(statisticsDbContainerUrl: sharedStorageUrls.statisticsFolderUrl)
    }
}
