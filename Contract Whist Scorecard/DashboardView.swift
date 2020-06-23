//
//  PersonalDashboard.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class DashboardView : UIView, DashboardActionDelegate {
    
    @IBOutlet public weak var delegate: DashboardActionDelegate!
    @IBOutlet private weak var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(withNibName nibName: String, frame: CGRect) {
        self.init(frame: frame)
        self.loadDashboardView(withNibName: nibName)
    }
            
    private func loadDashboardView(withNibName nibName: String) {
        Bundle.main.loadNibNamed(nibName, owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    // MARK: - Dashboard Action Delegate - pass-through ========================================== -
    
    func action(view: DashboardDetailView) {
        self.delegate?.action(view: view)
    }
    
    func getValue(value: DashboardValue, personal: Bool) -> Int {
        return self.delegate?.getValue(value: value, personal: personal) ?? 0
    }
    
    func getHistory(count: Int, personal: Bool) -> [HistoryGame] {
        return self.delegate?.getHistory(count: count, personal: personal) ?? []
    }
    
    func getHighScores(personal: Bool) -> HighScores {
        return self.delegate?.getHighScores(personal: personal) ?? HighScores()
    }
    
    func getStats(playerUUID: String) -> PlayerMO {
        return self.delegate?.getStats(playerUUID: playerUUID) ?? PlayerMO()
    }
}
