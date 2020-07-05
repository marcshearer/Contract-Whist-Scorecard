//
//  HighScoresViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

enum HighScoreType: Int {
    case totalScore = 1
    case handsMade = 2
    case twosMade = 3
    case winStreak = 4
    
    var playerKey: String {
        switch self {
        case .totalScore: return "maxScore"
        case .handsMade: return "maxMade"
        case .twosMade: return "maxTwos"
        case .winStreak: return "maxWinStreak"
        }
    }
    var participantKey: String {
        switch self {
        case .totalScore: return "totalScore"
        case .handsMade: return "handsMade"
        case .twosMade: return "twosMade"
        case .winStreak: return ""
        }
    }
}

class HighScoresViewController: ScorecardViewController {
    
    // MARK: - Class Properties ======================================================================== -
        
    // Properties to pass state
    private var backText = "Back"
    private var backImage = "back"
    
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var finishButton: ClearButton!
    @IBOutlet private weak var bannerTitleLabel: UILabel!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        finishPressed(finishButton)
    }
  
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.contentViewHeightConstraint.constant =
                       (ScorecardUI.landscapePhone() ? ScorecardUI.screenWidth
                           : self.view.frame.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom)
    }
        
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, backText: String = "Back", backImage: String = "back") -> HighScoresViewController? {
        
        let storyboard = UIStoryboard(name: "HighScoresViewController", bundle: nil)
        let highScoresViewController: HighScoresViewController = storyboard.instantiateViewController(withIdentifier: "HighScoresViewController") as! HighScoresViewController
        
        highScoresViewController.preferredContentSize = CGSize(width: 400, height: 700)
        highScoresViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        highScoresViewController.backText = backText
        highScoresViewController.backImage = backImage
        
        viewController.present(highScoresViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return highScoresViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension HighScoresViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.finishButton.setTitleColor(Palette.bannerText, for: .normal)
        self.bannerTitleLabel.textColor = Palette.bannerText
        
        self.view.backgroundColor = Palette.highScores
    }
}
