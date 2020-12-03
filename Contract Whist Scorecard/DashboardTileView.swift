//
//  DashboardTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol DashboardTileDelegate : class {
    
    var helpId: String {get}
    
    @objc optional func reloadData()
    
    @objc optional func didRotate()
    
    @objc optional func willDisappear()
    
    @objc optional func addHelp(to helpView: HelpView)
}

class DashboardTileView: UIView, DashboardTileDelegate {
    
    internal var detailType: DashboardDetailType = .history
    internal var helpId: String { "" }
    
    @IBInspectable internal var title: String = ""
    @IBInspectable internal var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable internal var personal: Bool = true
    @IBInspectable internal var hideTwos: Bool = false
    @IBInspectable internal var hideNoTwos: Bool = false
    
    @IBOutlet internal weak var dashboardDelegate: DashboardActionDelegate?
    @IBOutlet internal weak var parentDashboardView: DashboardView?

    @IBOutlet internal weak var contentView: UIView!
    @IBOutlet internal weak var tileView: UIView!
    @IBOutlet internal weak var titleLabel: UILabel!
    @IBOutlet internal weak var typeButton: ClearButton!

}
