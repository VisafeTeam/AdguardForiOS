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
import Sentry

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    //MARK: - Properties
    let statusBarWindow: IStatusBarWindow
    var window: UIWindow?
    
    // AppDelegate+StatusBarWindow notifications
    var filtersUpdateStarted: SafariAdGuardSDK.NotificationToken?
    var filtersUpdateFinished: SafariAdGuardSDK.NotificationToken?
    var contentBlockersUpdateStarted: SafariAdGuardSDK.NotificationToken?
    var contentBlockersUpdateFinished: SafariAdGuardSDK.NotificationToken?
    var orientationChangeNotification: NotificationToken?
    // AppDelegate addPurchaseStatusObserver notifications
    private var purchaseObservation: NotificationToken?
    private var proStatusObservation: NotificationToken?
    private var setappObservation: NotificationToken?
    
    private var firstRun: Bool {
        get {
            resources.firstRun
        }
        set {
            resources.firstRun = newValue
        }
    }
    private var activateWithOpenUrl: Bool = false

    //MARK: - Services
    private var resources: AESharedResourcesProtocol
    private var safariProtection: SafariProtectionProtocol
    private var dnsProtection: DnsProtectionProtocol
    private var purchaseService: PurchaseServiceProtocol
    private var dnsFiltersService: DnsFiltersServiceProtocol
    private var networking: ACNNetworking
    private var configuration: ConfigurationServiceProtocol
    private var productInfo: ADProductInfoProtocol
    private var userNotificationService: UserNotificationServiceProtocol
    private var vpnManager: VpnManagerProtocol
    private var setappService: SetappServiceProtocol
    private var rateService: RateAppServiceProtocol
    private var complexProtection: ComplexProtectionServiceProtocol
    private var themeService: ThemeServiceProtocol
    
    //MARK: - Application init
    override init() {
        StartupService.start()
        self.resources = ServiceLocator.shared.getService()!
        self.safariProtection = ServiceLocator.shared.getService()!
        self.purchaseService = ServiceLocator.shared.getService()!
        self.dnsFiltersService = ServiceLocator.shared.getService()!
        self.networking = ServiceLocator.shared.getService()!
        self.configuration = ServiceLocator.shared.getService()!
        self.productInfo = ServiceLocator.shared.getService()!
        self.userNotificationService = ServiceLocator.shared.getService()!
        self.vpnManager = ServiceLocator.shared.getService()!
        self.setappService = ServiceLocator.shared.getService()!
        self.rateService = ServiceLocator.shared.getService()!
        self.complexProtection = ServiceLocator.shared.getService()!
        self.themeService = ServiceLocator.shared.getService()!
        self.safariProtection = ServiceLocator.shared.getService()!
        self.dnsProtection = ServiceLocator.shared.getService()!
        
        self.statusBarWindow = StatusBarWindow(configuration: configuration)
        super.init()
    }
    
    deinit {
        resources.sharedDefaults().removeObserver(self, forKeyPath: TunnelErrorCode)
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        //------------- Preparing for start application. Stage 1. -----------------
        
        activateWithOpenUrl = false
        
        initLogger()
        DDLogInfo("(AppDelegate) Preparing for start application. Stage 1.")
        
        //------------ Interface Tuning -----------------------------------
        self.window?.backgroundColor = UIColor.clear
        
        if (application.applicationState != .background) {
            purchaseService.checkPremiumStatusChanged()
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        SentrySDK.start { options in
            options.dsn = SentryConst.dsnUrl
            options.enableAutoSessionTracking = false
        }
        
        prepareControllers()
        
        //------------- Preparing for start application. Stage 2. -----------------
        DDLogInfo("(AppDelegate) Preparing for start application. Stage 2.")
        
        AppDelegate.setPeriodForCheckingFilters()
        subscribeToNotifications()
        
        // Background fetch consists of 3 steps, so if the update process didn't fully finish in the background than we should continue it here
        safariProtection.finishBackgroundUpdate { error in
            if let error = error {
                DDLogError("(AppDelegate) - didFinishLaunchingWithOptions; Finished background update with error: \(error)")
                return
            }
            DDLogInfo("(AppDelegate) - didFinishLaunchingWithOptions; Finish background update successfully")
        }
        
        return true
    }
    
    
    //MARK: - Application Delegate Methods
    
    func applicationWillResignActive(_ application: UIApplication) {
        DDLogInfo("(AppDelegate) applicationWillResignActive.")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DDLogInfo("(AppDelegate) applicationDidEnterBackground.")
        resources.synchronizeSharedDefaults()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        DDLogInfo("(AppDelegate) applicationWillEnterForeground.")
        configuration.checkContentBlockerEnabled()
        let safariConfig = SafariConfiguration(resources: resources, isProPurchased: purchaseService.isProPurchased)
        let dnsConfig = DnsConfiguration(resources: resources, isProPurchased: purchaseService.isProPurchased)
        safariProtection.updateConfig(with: safariConfig)
        dnsProtection.updateConfig(with: dnsConfig)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DDLogInfo("(AppDelegate) applicationDidBecomeActive.")
        initStatusBarNotifications(application)
        
        // If theme mode is System Default gets current style
        setAppInterfaceStyle()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        DDLogInfo("(AppDelegate) applicationWillTerminate.")
        resources.synchronizeSharedDefaults()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        addPurchaseStatusObserver()
        purchaseService.checkLicenseStatus()
        
        // Update filters in background
        safariProtection.updateSafariProtectionInBackground { [weak self] result in
            if let error = result.error {
                DDLogError("(AppDelegate) - backgroundFetch; Received error from SDK: \(error)")
                completionHandler(result.backgroundFetchResult)
            }
            // If there was a fase with donwloading filters, than we need to restart tunnel to apply newest ones
            else if result.oldBackgroundFetchState == .updateFinished || result.oldBackgroundFetchState == .loadAndSaveFilters {
                self?.vpnManager.updateSettings { _ in
                    completionHandler(result.backgroundFetchResult)
                }
            }
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        DDLogError("(AppDelegate) application Open URL.")
        activateWithOpenUrl = true
        
        if setappService.openUrl(url, options: options) {
            return true
        }
        
        let urlParser: IURLSchemeParser = URLSchemeParser(executor: self,
                                                          configurationService: configuration,
                                                          purchaseService: purchaseService)
        
        return urlParser.parse(url: url)
    }
    
    //MARK: - Public methods
    
    func resetAllSettings() {
        let resetProcessor = SettingsResetor(appDelegate: self,
                                             dnsFiltersService: dnsFiltersService,
                                             vpnManager: vpnManager,
                                             resources: resources,
                                             purchaseService: purchaseService,
                                             safariProtection: safariProtection)
        resetProcessor.resetAllSettings()
    }
    
    func setAppInterfaceStyle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let window = self.window else { return }
            if #available(iOS 13.0, *) {
                switch (window.traitCollection.userInterfaceStyle) {
                case .dark:
                    self.configuration.systemAppearenceIsDark = true
                default:
                    self.configuration.systemAppearenceIsDark = false
                }
            } else {
                self.configuration.systemAppearenceIsDark = false
            }
        }
    }
    
    // MARK: - Observing Values from User Defaults
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == TunnelErrorCode, resources.tunnelErrorCode == 3 {
            postDnsFiltersOverlimitNotificationIfNedeed()
        }
    }
    
    //MARK: - Private methods
    
    private func prepareControllers() {
        setappService.start()
        
        guard let mainPageController = getMainPageController() else {
            DDLogError("mainPageController is nil")
            return
        }
        
        mainPageController.onReady = { [weak self] in
            // request permission for user notifications posting
            self?.userNotificationService.requestPermissions()
            
            // Show rate app dialog when main page is initialized
            self?.showRateAppDialogIfNedeed()
        }
        
        guard let dnsLogContainerVC = getDnsLogContainerController() else {
            DDLogError("dnsLogContainerVC is nil")
            return
        }
        /**
         To quickly show stats in ActivityViewController, we load ViewController when app starts
         */
        dnsLogContainerVC.loadViewIfNeeded()
    }
    
    
    private func postDnsFiltersOverlimitNotificationIfNedeed(){
        let rulesNumberString = String.simpleThousandsFormatting(NSNumber(integerLiteral: dnsFiltersService.enabledRulesCount))
        let title = String.localizedString("dns_filters_notification_title")
        let body = String(format: String.localizedString("dns_filters_overlimit_title"), rulesNumberString)
        let userInfo: [String : Int] = [PushNotificationCommands.command : PushNotificationCommands.openDnsFiltersController.rawValue]
        userNotificationService.postNotification(title: title, body: body, userInfo: userInfo)
    }
    
    private func showRateAppDialogIfNedeed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if self.rateService.shouldShowRateAppDialog {
                AppDelegate.shared.presentRateAppController()
                self.resources.rateAppShown = true
            }
        }
    }
    
    private func addPurchaseStatusObserver() {
         if purchaseObservation == nil {
             purchaseObservation = NotificationCenter.default.observe(name: Notification.Name(PurchaseService.kPurchaseServiceNotification), object: nil, queue: nil) { (notification) in
                 guard let type =  notification.userInfo?[PurchaseService.kPSNotificationTypeKey] as? String else { return }
                 
                 DDLogInfo("(AppDelegate) - Received notification type = \(type)")
                 
                 if type == PurchaseService.kPSNotificationPremiumExpired {
                     self.userNotificationService.postNotification(title: String.localizedString("premium_expired_title"), body: String.localizedString("premium_expired_message"), userInfo: nil)
                 }
             }
         }
         
         if proStatusObservation == nil {
             proStatusObservation = NotificationCenter.default.observe(name: .proStatusChanged, object: nil, queue: .main) { [weak self] _ in
                 guard let self = self else { return }
                 
                 if !self.configuration.proStatus && self.vpnManager.vpnInstalled {
                     DDLogInfo("(AppDelegate) Remove vpn configuration")
                     self.vpnManager.removeVpnConfiguration { (error) in
                         if error != nil {
                             DDLogError("(AppDelegate) Remove vpn configuration failed: \(error!)")
                         }
                     }
                 }
             }
         }
     }
    
    private func subscribeToNotifications() {
        subscribeToUserNotificationServiceNotifications()
        
        resources.sharedDefaults().addObserver(self, forKeyPath: TunnelErrorCode, options: .new, context: nil)
        
        subscribeToThemeChangeNotification()
        
        setappObservation = NotificationCenter.default.observe(name: .setappDeviceLimitReched, object: nil, queue: OperationQueue.main) { _ in
            if let vc = Self.topViewController() {
                    ACSSystemUtils.showSimpleAlert(for: vc, withTitle: String.localizedString("common_error_title"), message: String.localizedString("setapp_device_limit_reached"))
                    
            }
        }
    }
    
    //MARK: - Init logger
    
    private func initLogger() {
        let isDebugLogs = resources.sharedDefaults().bool(forKey: AEDefaultsDebugLogs)
        DDLogInfo("(AppDelegate) Init app with loglevel %s", level: isDebugLogs ? .debug : .all)
        ACLLogger.singleton()?.initLogger(resources.sharedAppLogsURL())
        ACLLogger.singleton()?.logLevel = isDebugLogs ? ACLLDebugLevel : ACLLDefaultLevel
        
        #if DEBUG
        ACLLogger.singleton()?.logLevel = ACLLDebugLevel
        #endif
        
        AGLogger.setLevel(isDebugLogs ? .AGLL_TRACE : .AGLL_INFO)
        AGLogger.setCallback { msg, length in
            guard let msg = msg else { return }
            let data = Data(bytes: msg, count: Int(length))
            if let str = String(data: data, encoding: .utf8) {
                DDLogInfo("(DnsLibs) \(str)")
            }
        }
    
        DDLogInfo("Application started. Version: \(productInfo.buildVersion() ?? "nil")")
        
        // TODO: - Add this to all extensions that use AdGuarSDK
        Logger.logDebug = { msg in
            DDLogDebug(msg)
        }
        
        Logger.logInfo = { msg in
            DDLogInfo(msg)
        }
        
        Logger.logError = { msg in
            DDLogError(msg)
        }
    }
}
