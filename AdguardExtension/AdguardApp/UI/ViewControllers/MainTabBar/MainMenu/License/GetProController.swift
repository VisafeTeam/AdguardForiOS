//
// This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
// Copyright © Adguard Software Limited. All rights reserved.
//
// Adguard for iOS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Adguard for iOS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Adguard for iOS. If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

protocol GetProControllerDelegate {
    func getProControllerClosed()
}

class GetProController: UIViewController {

    var needsShowingExitButton = false
    var getProControllerDelegate: GetProControllerDelegate?

    // MARK: - properties
    private var notificationObserver: Any?
    private var notificationToken: NotificationToken?

    private let purchaseService: PurchaseServiceProtocol = ServiceLocator.shared.getService()!
    private let configurationService: ConfigurationServiceProtocol = ServiceLocator.shared.getService()!
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let productInfo: ADProductInfoProtocol = ServiceLocator.shared.getService()!

    // MARK: - IB outlets
    @IBOutlet weak var accountView: UIView!
    @IBOutlet weak var myAccountButton: RoundRectButton!

    @IBOutlet weak var separator2: UIView!

    @IBOutlet var loginBarButton: UIBarButtonItem!
    @IBOutlet var logoutBarButton: UIBarButtonItem!
    @IBOutlet var exitButton: UIBarButtonItem!
    @IBOutlet weak var goToMyAccountHeight: NSLayoutConstraint!

    // MARK: - constants

    private let accountAction = "account"
    private let from = "license"

    private let getProSegueIdentifier = "getProSegue"
    private var getProTableController: GetProTableController? = nil

    private var purchaseObserver: NotificationToken?

    // MARK: - View Controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        purchaseObserver = NotificationCenter.default.observe(name: Notification.Name(PurchaseAssistant.kPurchaseServiceNotification),
                                               object: nil, queue: nil)
        { [weak self](notification) in

            DispatchQueue.main.async {
                if let info = notification.userInfo {
                    self?.processNotification(info: info)
                    self?.updateViews()
                    self?.updateTheme()
                }
            }
        }

        updateViews()
        updateTheme()

        myAccountButton.makeTitleTextCapitalized()

        if needsShowingExitButton {
            navigationItem.leftBarButtonItems = [exitButton]
        } else {
            setupBackButton()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let isBigScreen = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .regular
        myAccountButton.contentEdgeInsets.left = isBigScreen ? 24.0 : 16.0
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - actions
    @IBAction func exitAction(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true) {[weak self] in
            self?.getProControllerDelegate?.getProControllerClosed()
        }
    }

    @IBAction func accountAction(_ sender: Any) {
        UIApplication.shared.openAdguardUrl(action: accountAction, from: from, buildVersion: productInfo.buildVersion())
    }

    @IBAction func logoutAction(_ sender: UIBarButtonItem) {

        let alert = UIAlertController(title: nil, message: String.localizedString("confirm_logout_text"), preferredStyle: .deviceAlertStyle)

        let cancelAction = UIAlertAction(title: String.localizedString("common_action_cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)

        let okAction = UIAlertAction(title: String.localizedString("common_action_yes"), style: .destructive) {
            [weak self] (action) in
            if self?.purchaseService.logout() ?? false {
                DispatchQueue.main.async {
                    self?.updateViews()
                }
            }
        }
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }


    // MARK: - prepare for segue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == getProSegueIdentifier {
            if let destinationVC = segue.destination as? GetProTableController {
                getProTableController = destinationVC
            }
        }
    }


    // MARK: - private methods

    private func processNotification(info: [AnyHashable: Any]) {

        DispatchQueue.main.async { [weak self] in
            let type = info[PurchaseAssistant.kPSNotificationTypeKey] as? String
            let error = info[PurchaseAssistant.kPSNotificationErrorKey] as? NSError

            switch type {
            case PurchaseAssistant.kPSNotificationPurchaseSuccess:
                self?.purchaseSuccess()
            case PurchaseAssistant.kPSNotificationPurchaseFailure:
                self?.getProTableController?.enablePurchaseButtons(true)
                self?.purchaseFailure(error: error)
            case PurchaseAssistant.kPSNotificationRestorePurchaseSuccess:
                self?.restoreSuccess()
            case PurchaseAssistant.kPSNotificationRestorePurchaseNothingToRestore:
                self?.getProTableController?.enablePurchaseButtons(true)
                self?.nothingToRestore()
            case PurchaseAssistant.kPSNotificationRestorePurchaseFailure:
                self?.getProTableController?.enablePurchaseButtons(true)
                self?.restoreFailed(error: error)
            case PurchaseAssistant.kPSNotificationReadyToPurchase:
                self?.getProTableController?.selectedProduct = self?.purchaseService.standardProduct
                self?.getProTableController?.enablePurchaseButtons(true)
                self?.getProTableController?.setPrice()
            case PurchaseAssistant.kPSNotificationCanceled:
                self?.getProTableController?.enablePurchaseButtons(true)
            default:
                break
            }
        }
    }

    private func purchaseSuccess(){
        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("purchase_success_message")) {
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func purchaseFailure(error: Error?) {
        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("purchase_failure_message"))
    }

    private func restoreSuccess(){
        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("restore_success_message")) {
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func nothingToRestore() {
        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("nothing_to_restore_message"))
    }

    private func restoreFailed(error: NSError?) {
        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("restore_purchases_failure_message"))
        getProTableController?.enablePurchaseButtons(true)
    }

    private func updateViews() {

        switch (configurationService.proStatus, purchaseService.purchasedThroughLogin) {
        case (false, _):
            goToMyAccountHeight.constant = 0
            navigationItem.rightBarButtonItems = [loginBarButton]
        case (true, false):
            goToMyAccountHeight.constant = 0
            navigationItem.rightBarButtonItems = []
        case (true, true):
            goToMyAccountHeight.constant = 60
            navigationItem.rightBarButtonItems = [logoutBarButton]
        }

        (children.first as? UITableViewController)?.tableView.reloadData()
    }
}

extension GetProController: ThemableProtocol {
    func updateTheme() {
        view.backgroundColor = theme.backgroundColor
        separator2.backgroundColor = theme.separatorColor
        theme.setupNavigationBar(navigationController?.navigationBar)
    }
}
