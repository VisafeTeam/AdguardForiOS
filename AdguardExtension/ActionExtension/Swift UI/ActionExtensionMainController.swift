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

import UIKit
import CoreServices
import AdGuardSDK

@objcMembers
class ActionExtensionMainController: UITableViewController {
    
    
    @IBOutlet var enabledSwitch: UISwitch!
    @IBOutlet weak var domainLabel: ThemableLabel!
    
    @IBOutlet var themableLabels: [ThemableLabel]!
    
    var domainName: String?
    var url: URL?
    var iconUrl: URL?
    var enableChangeDomainFilteringStatus: Bool = false
    var domainEnabled: Bool = false
    var injectScriptSupported: Bool = false
    
    var resources: AESharedResourcesProtocol?
    var safariProtection: SafariProtectionProtocol?
    var webReporter: ActionWebReporterProtocol?
    var theme: ThemeServiceProtocol?
    var configuration: SimpleConfigurationSwift?
    
    var enabledHolder: Bool?
    
    private let toggleQueue = DispatchQueue(label: "toggle_queue")
    
    var systemStyleIsDark: Bool {
        if #available(iOSApplicationExtension 13.0, *) {
            switch traitCollection.userInterfaceStyle {
            case .light:
                return false
            case .dark:
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }
    
    // MARK: - ViewController Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Constants.aeProductName()
        
        configuration = SimpleConfigurationSwift(withResources: resources!, systemAppearenceIsDark: systemStyleIsDark)
        self.theme = ThemeService(configuration!)
        
        enabledSwitch.isOn = domainEnabled
        enabledHolder = domainEnabled
        domainLabel.text = domainName
        
        // todo: maybe we should use it asyncronously
        let states = safariProtection?.allContentBlockersStates
        let disabled = !(states?.contains(where: { (_, enabled) in
            return !enabled
        }) ?? true)
        
        if (!disabled){
            DispatchQueue.main.async{[weak self] in
                guard let sSelf = self else { return }
                ACSSystemUtils.showSimpleAlert(for: sSelf, withTitle: String.localizedString("common_warning_title"), message: String.localizedString("content_blocker_disabled_format"))
            }
        }

        updateTheme()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }
    
    deinit {
        DDLogDebug("(AEAUIMainController) run deinit.")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        configuration?.systemAppearenceIsDark = systemStyleIsDark
        updateTheme()
    }
    
    @IBAction func toggleStatus(_ sender: UISwitch) {
        
        // make changes one at a time
        let group = DispatchGroup()
        toggleQueue.async { [weak self] in
            ProcessInfo().performExpiringActivity(withReason: "Loading json to content blocker") {[weak self] (expired) in
                guard let self = self else { return }
                
                if (expired) {
                    return
                }
                
                let newEnabled = sender.isOn
                
                if newEnabled == self.domainEnabled {
                    return
                }
                //check rule overlimit
                if !(self.enableChangeDomainFilteringStatus) {
                    DispatchQueue.main.async {
                        ACSSystemUtils.showSimpleAlert(for: self, withTitle: String.localizedString("common_error_title"), message: String.localizedString("filter_rules_maximum"))
                        self.enabledSwitch.isOn = self.domainEnabled
                    }
                    return
                }
                
                let inverted: Bool = self.resources!.sharedDefaults().bool(forKey: AEDefaultsInvertedWhitelist)
                
                group.enter()
                // disable filtering == remove from inverted whitelist
                if inverted && self.domainEnabled{
                    self.safariProtection?.removeRule(withText: self.domainName!, for: .invertedAllowlist) {[weak self] (error) in
                        self?.domainEnabled = false
                        group.leave()
                    }
                }
                // enable filtering == add to inverted whitelist
                else if (inverted && !(self.domainEnabled)) {
                    self.safariProtection?.add(rule: UserRule(ruleText: self.domainName!), for: .invertedAllowlist, override: true) {[weak self] (error) in
                        self?.domainEnabled = true
                        group.leave()
                    }
                }
                // disable filtering (add to whitelist)
                else if self.domainEnabled{
                    self.safariProtection?.add(rule: UserRule(ruleText: self.domainName!), for: .allowlist, override: true) { [weak self] (error) in
                        guard let sSelf = self else { return }
                        DispatchQueue.main.async {
                            if error != nil {
                                sSelf.enabledSwitch.isOn = sSelf.domainEnabled
                            } else {
                                sSelf.domainEnabled = newEnabled
                            }
                            group.leave()
                        }
                    }
                }
                // enable filtering (remove from whitelist)
                else {
                    self.safariProtection?.removeRule(withText: self.domainName!, for: .allowlist) {[weak self] (error) in
                        guard let sSelf = self else { return }
                        DispatchQueue.main.async {
                            if error != nil {
                                sSelf.enabledSwitch.isOn = sSelf.domainEnabled
                            } else {
                                sSelf.domainEnabled = newEnabled
                            }
                            group.leave()
                        }
                    }
                }
                
                group.wait()
            }
        }
    }
    
    @IBAction func clickedMissedAd(_ sender: UITapGestureRecognizer) {
        guard let url = webReporter?.composeWebReportUrl(self.url) else { return }
        openWithUrl(url)
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @IBAction func clickedBlockElement(_ sender: UITapGestureRecognizer) {
        if injectScriptSupported{
            let extensionItem = NSExtensionItem()
            let settings = ["urlScheme": AE_URLSCHEME]
            let obj: NSItemProvider = NSItemProvider(item:
                 [ NSExtensionJavaScriptFinalizeArgumentKey  : [
                    "blockElement": NSNumber(value: 1),
                    "settings": settings
                ]] as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))
           
            extensionItem.attachments = [obj]
            if let context = self.extensionContext{
                context.completeRequest(returningItems: [extensionItem], completionHandler: nil)
            }
        }
        else{
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: String.localizedString("common_error_title"), message: String.localizedString("assistant_launching_unable"))
            enabledSwitch.isOn = domainEnabled
        }
    }
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        let extensionItem = NSExtensionItem()
        let obj: NSItemProvider = NSItemProvider(item:
            [ NSExtensionJavaScriptFinalizeArgumentKey  : [
                "needReload": "\(enabledHolder != self.domainEnabled)"
                ]] as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))
        
        extensionItem.attachments?.append(obj)
        if let context = self.extensionContext{
            context.completeRequest(returningItems: [extensionItem], completionHandler: nil)
        }
    }
    
// MARK: - Tableview delegates
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        theme?.setupTableCell(cell)
        return cell
    }
    
// MARK: - Private Methods
    
    @objc private func openWithUrl(_ url: URL?) {
        guard let Url = url else { return }
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while responder != nil{
            if responder?.responds(to: selector) ?? false{
                responder?.perform(selector, with: Url)
            }
            responder = responder?.next
        }
    }
    
    private func updateTheme() {
        theme?.setupTable(tableView)
        theme?.setupSwitch(enabledSwitch)
        theme?.setupNavigationBar(navigationController?.navigationBar)
        theme?.setupLabels(themableLabels)
        view.backgroundColor = theme?.backgroundColor
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.tableView.reloadData()
        }
    }
}
