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

class ContentBlockerStateController: UITableViewController {
    // Поправить init в dataSource
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let contentBlockerService: ContentBlockerService = ServiceLocator.shared.getService()!
    private let contentBlockersDataSource = ContentBlockersDataSource()
    
    
    private let reuseIdentifier = "contentBlockerStateCell"
    
    private let groupsByIntAndContentBlockerType : [Int : ContentBlockerType] = [
        0 : .general,
        1 : .privacy,
        2 : .custom,
        3 : .socialWidgetsAndAnnoyances,
        4 : .other
    ]
    
    private let groupsByContentBlockerTypeAndInt : [ContentBlockerType : Int] = [
        .general : 0,
        .privacy : 1,
        .custom : 2,
        .socialWidgetsAndAnnoyances : 3,
        .other : 4
    ]
    
    @IBOutlet weak var tableFooterView: UIView!
    
    // MARK: - ViewController life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        addObservers()
        self.title = ACLocalizedString("content_blockers_title", nil)
        updateTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTheme()
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contentBlockersDataSource.contentBlockers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as? ContentBlockerStateCell {
            
            theme.setupTableCell(cell)
            theme.setupLabels(cell.themableLabels)
            
            guard let type = groupsByIntAndContentBlockerType[indexPath.row] else { return UITableViewCell() }
            cell.layoutSubviews()
            cell.blockerState = contentBlockersDataSource.contentBlockers[type]!
            return cell
        }else{
           return UITableViewCell()
        }
    }
    
    // MARK: - private methods
    
    private func updateTheme() {
        view.backgroundColor = theme.backgroundColor
        tableFooterView.backgroundColor = theme.backgroundColor
        //theme.setupLabels(themableLabels)
        theme.setupNavigationBar(navigationController?.navigationBar)
        theme.setupTable(tableView)
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private func addObservers(){
        // User interface style observer
        NotificationCenter.default.addObserver(forName: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: OperationQueue.main) {[weak self] (notification) in
                   self?.updateTheme()
               }
        
        // Start of filter update observing
        NotificationCenter.default.addObserver(forName: SafariService.filterBeganUpdating, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            
            guard let type = notification.userInfo?["contentBlockerType"] as! ContentBlockerType? else { return }
            self?.contentBlockersDataSource.contentBlockers[type]?.currentState = .updating
            self?.reloadRaw(with: type)
        }
        
        // Finish of filter update observer
        NotificationCenter.default.addObserver(forName: SafariService.filterFinishedUpdating, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            
            guard let type = notification.userInfo?["contentBlockerType"] as! ContentBlockerType? else { return }
            
            guard let success = notification.userInfo?["success"] as? Bool else { return }
            if !success {
                self?.contentBlockersDataSource.contentBlockers[type]?.currentState = .failedUpdating
                self?.reloadRaw(with: type)
            } else {
                let blocker = self?.contentBlockersDataSource.contentBlockers[type]
                self?.contentBlockersDataSource.contentBlockers[type]?.currentState = (blocker?.numberOfOverlimitedRules == nil) ? (blocker?.enabled ?? false ? .enabled : .disabled) : .overLimited
                self?.reloadRaw(with: type)
            }
        }
        
        // App did become active observer
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            self?.contentBlockersDataSource.updateContentBlockersArray()
            self?.tableView.reloadData()
        }
    }
    
    private func reloadRaw(with type: ContentBlockerType){
        let raw = groupsByContentBlockerTypeAndInt[type]!
        let indexPath = IndexPath(row: raw, section: 0)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    private func setupTableView(){
        let nib = UINib.init(nibName: "ContentBlockerStateCell", bundle: nil)
        self.tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
    }
}
