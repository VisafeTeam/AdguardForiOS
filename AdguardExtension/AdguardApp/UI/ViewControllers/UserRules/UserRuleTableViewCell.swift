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

protocol UserRuleTableViewCellDelegate: AnyObject {
    func ruleStateChanged(_ rule: String, newState: Bool)
}

struct UserRuleCellModel {
    let rule: String
    var isEnabled: Bool
    var isSelected: Bool
}

final class UserRuleTableViewCell: UITableViewCell, Reusable {
    
    weak var delegate: UserRuleTableViewCellDelegate?
    var model: UserRuleCellModel! {
        didSet {
            stateButton.isSelected = model.isEnabled
            ruleLabel.text = model.rule
        }
    }
    
    private lazy var stateButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "check-off"), for: .normal)
        button.setImage(UIImage(named: "check-on"), for: .selected)
        button.addTarget(self, action: #selector(ruleStateChanged(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var ruleLabel: ThemableLabel = {
        let label = ThemableLabel()
        label.greyText = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: isIpadTrait ? 20.0 : 16.0, weight: .regular)
        return label
    }()
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(stateButton)
        contentView.addSubview(ruleLabel)
        
        NSLayoutConstraint.activate([
            stateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            stateButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stateButton.widthAnchor.constraint(equalToConstant: 24.0),
            stateButton.heightAnchor.constraint(equalToConstant: 24.0),
            
            ruleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14.0),
            ruleLabel.leadingAnchor.constraint(equalTo: stateButton.trailingAnchor, constant: 16.0),
            ruleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            ruleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14.0)
        ])
    }
    
    // MARK: - Internal methods
    
    func updateTheme(_ themeService: ThemeServiceProtocol) {
        themeService.setupLabel(ruleLabel)
        themeService.setupTableCell(self)
    }
    
    // MARK: - Private methods
    
    @objc private final func ruleStateChanged(_ sender: UIButton) {
        let newState = !sender.isSelected
        sender.isSelected = newState
        model.isEnabled = newState
        delegate?.ruleStateChanged(model.rule, newState: newState)
    }
}
