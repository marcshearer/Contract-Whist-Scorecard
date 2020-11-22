//
//  AwardDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

protocol AwardDetail {
    
    func show(title: String, awards: Awards, playerUUID: String, award: Award, mode: AwardDetailMode)
    
}

class AwardDetailViewController: ScorecardViewController, AwardDetail, DetailDelegate {
    
    var isVisible: Bool { return true }
    var detailView: UIView { return self.view }
    
    @IBOutlet private weak var awardTitleLabel: UILabel!
    @IBOutlet private weak var awardDetailView: AwardDetailView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = Palette.banner.background
        self.awardTitleLabel.textColor = Palette.banner.text
        self.awardDetailView.set(backgroundColor: Palette.banner.background, textColor: Palette.banner.text, detailFont: UIFont.systemFont(ofSize: 17), shadow: false, dismiss: false, widthPercent: 100)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
    }
    
    internal func show(title: String, awards: Awards, playerUUID: String, award: Award, mode: AwardDetailMode) {
        self.awardTitleLabel.text = title
        self.awardDetailView.set(awards: awards, playerUUID: playerUUID, award: award, mode: mode)
    }
    
    class func create() -> AwardDetailViewController {
        let storyboard = UIStoryboard(name: "AwardDetailViewController", bundle: nil)
        let awardDetailViewController = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as! AwardDetailViewController

        return awardDetailViewController
    }
    
}

