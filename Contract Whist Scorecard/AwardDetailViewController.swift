//
//  AwardDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

protocol AwardDetail {
    
    func show(awards: Awards, playerUUID: String, award: Award, mode: AwardDetailMode)
    
}

class AwardDetailViewController: ScorecardViewController, AwardDetail {
    
    @IBOutlet private weak var awardDetailView: AwardDetailView!
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.awardDetailView.set(backgroundColor: Palette.banner.background, textColor: Palette.banner.text, detailFont: UIFont.systemFont(ofSize: 17), shadow: false, dismiss: false, widthPercent: 100)
    }
    
    internal func show(awards: Awards, playerUUID: String, award: Award, mode: AwardDetailMode) {
        self.awardDetailView.set(awards: awards, playerUUID: playerUUID, award: award, mode: mode)
    }
    
    class func create() -> AwardDetailViewController {
        let storyboard = UIStoryboard(name: "AwardDetailViewController", bundle: nil)
        let historyDetailViewController = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as! AwardDetailViewController
        return historyDetailViewController
    }
    
}
