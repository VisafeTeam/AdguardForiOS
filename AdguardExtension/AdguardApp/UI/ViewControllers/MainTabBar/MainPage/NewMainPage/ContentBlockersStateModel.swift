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

import Foundation

protocol ContentBlockersStateModelDelegate: AnyObject {
    func contentBlockersStateChanged()
}

protocol ContentBlockersStateModelProtocol: AnyObject {
    var shouldShowContentBlockersView: Bool { get }
}

final class ContentBlockersStateModel: ContentBlockersStateModelProtocol {
    
    weak var delegate: ContentBlockersStateModelDelegate?
    
    private(set) var shouldShowContentBlockersView: Bool = false {
        didSet {
            if oldValue != shouldShowContentBlockersView {
                delegate?.contentBlockersStateChanged()
            }
        }
    }
    
    private var contentBlockersStateObserver: NSKeyValueObservation?
    private let configuration: ConfigurationService
    
    init(configuration: ConfigurationService) {
        self.configuration = configuration
        configuration.checkContentBlockerEnabled()
        
        contentBlockersStateObserver = configuration.observe(\.contentBlockerEnabled) { (_, _) in
            DispatchQueue.main.async { [weak self] in
                self?.shouldShowContentBlockersView = !configuration.allContentBlockersEnabled
            }
        }
        
        shouldShowContentBlockersView = !configuration.allContentBlockersEnabled
    }
}
