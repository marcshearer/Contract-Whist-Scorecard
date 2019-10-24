//
//  OverrideViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class OverrideViewController : CustomViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {
    
    private enum Options: Int, CaseIterable {
        case excludeHistory = 0
        case excludeStats = 1
        case subHeading = 2
        case startCards = 3
        case endCards = 4
        case bounce = 5
    }
    
    private let scorecard = Scorecard.shared
    
    private var message: String!
    private var formTitle: String!
    private var value = 1
    private var completion: (()->())?
    private var existingOverride = false
    private var existingSettings: GameSettings!
    private var skipOptions = 0
    
    // UI elements
    private var cardsSlider: [Int : UISlider] = [:]
    private var cardsValue: [Int : UITextField] = [:]
    private var bounceSelection: UISegmentedControl!
    private var excludeStatsSelection: UISegmentedControl!
    private var excludeHistorySelection: UISegmentedControl!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var revertButton: UIButton!
    @IBOutlet private weak var bannerContinuation: BannerContinuation!
    @IBOutlet private weak var bannerContinuationHeightConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.scorecard.overrideSelected = true
        self.completion?()
        self.dismiss()
    }
    
    @IBAction func revertPressed(_ sender: UIButton) {
        // Disable override
        if self.scorecard.overrideSettings != self.existingSettings {
            self.scorecard.resetOverrideSettings()
        }
        self.completion?()
        self.dismiss()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ScorecardUI.roundCorners(view)
        
        self.existingOverride = self.scorecard.overrideSelected
        
        if !self.existingOverride {
            self.scorecard.resetOverrideSettings()
        }
        self.existingSettings = self.scorecard.overrideSettings.copy()
        if !self.existingOverride {
            // Default to exclude stats
            self.scorecard.overrideSettings.excludeStats = true
        }
        
        self.skipOptions = (self.scorecard.settingSaveHistory ? 0 : 2)
        
        self.revertButton.setTitleColor(Palette.gameBannerText, for: .normal)
        self.confirmButton.setTitleColor(Palette.gameBannerText, for: .normal)

        self.enableButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        self.scorecard.reCenterPopup(self)
        if ScorecardUI.smallPhoneSize() || ScorecardUI.landscapePhone() {
            self.bannerContinuation.isHidden = true
            self.bannerContinuationHeightConstraint.constant = 0.0
        } else {
            self.bannerContinuation.isHidden = false
            self.bannerContinuationHeightConstraint.constant = 60.0
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.scorecard.settingSaveHistory {
            return Options.allCases.count
        } else {
            return Options.allCases.count - self.skipOptions
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        if let option = Options(rawValue: indexPath.row + skipOptions) {
            switch option {
            case .excludeHistory, .excludeStats:
                height = 80.0
            case .subHeading:
                height = 80.0
            case .startCards, .endCards:
                height = 32.0
            case .bounce:
                height = 45.0
            }
        }
        return height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: OverrideTableCell!
        
        if let option = Options(rawValue: indexPath.row + skipOptions) {
            switch option {
            case .excludeHistory:
                cell = tableView.dequeueReusableCell(withIdentifier: "Exclude", for: indexPath) as? OverrideTableCell
                cell.excludeLabel.attributedText = self.excludeText(from: "History")
                cell.excludeSelection.addTarget(self, action: #selector(OverrideViewController.excludeHistoryAction(_:)), for: UIControl.Event.valueChanged)
                cell.excludeSelection.selectedSegmentIndex = (self.scorecard.overrideSettings.excludeHistory ? 0 : 1)
                self.excludeHistorySelection = cell.excludeSelection
                self.excludeChanged()
                
            case .excludeStats:
                cell = tableView.dequeueReusableCell(withIdentifier: "Exclude", for: indexPath) as? OverrideTableCell
                cell.excludeLabel.attributedText = self.excludeText(from: "Statistics")
                cell.excludeSelection.addTarget(self, action: #selector(OverrideViewController.excludeStatsAction(_:)), for: UIControl.Event.valueChanged)
                cell.excludeSelection.selectedSegmentIndex = (self.scorecard.overrideSettings.excludeStats ? 0 : 1)
                self.excludeStatsSelection = cell.excludeSelection
                
            case .subHeading:
                cell = tableView.dequeueReusableCell(withIdentifier: "Sub Heading", for: indexPath) as? OverrideTableCell
                cell.subHeadingLabel.text = "Number of cards in hands"
                
            case .startCards, .endCards:
                let index = (option == .startCards ? 0 : 1)
                cell = tableView.dequeueReusableCell(withIdentifier: "Cards", for: indexPath) as? OverrideTableCell
                cell.cardsLabel.text = (index == 0 ? "Start:" : "End:")
                cell.cardsSlider.tag = index
                cell.cardsSlider.addTarget(self, action: #selector(OverrideViewController.cardsSliderAction(_:)), for: UIControl.Event.valueChanged)
                cell.cardsSlider.value = Float(self.scorecard.overrideSettings.cards[index])
                cell.cardsValue.text = "\(self.scorecard.overrideSettings.cards[index])"
                self.cardsSlider[index] = cell.cardsSlider
                self.cardsValue[index] = cell.cardsValue
                
            case .bounce:
                cell = tableView.dequeueReusableCell(withIdentifier: "Bounce", for: indexPath) as? OverrideTableCell
                cell.bounceSelection.addTarget(self, action: #selector(OverrideViewController.bounceAction(_:)), for: UIControl.Event.valueChanged)
                cell.bounceSelection.selectedSegmentIndex = (self.scorecard.overrideSettings.bounceNumberCards ? 1 : 0)
                cell.bounceSelection.layer.cornerRadius = 5.0
                self.bounceSelection = cell.bounceSelection
                self.cardsChanged()
                
            }
        }
        
        return cell as UITableViewCell
    }

    // MARK: - Action Handlers ========================================================================= -
    
    @objc internal func cardsSliderAction(_ sender: UISlider) {
        let index = sender.tag
        scorecard.overrideSettings.cards[index] = Int(cardsSlider[index]!.value)
        cardsValue[index]!.text = "\(scorecard.overrideSettings.cards[index])"
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func bounceAction(_ sender: Any) {
        scorecard.overrideSettings.bounceNumberCards = (bounceSelection.selectedSegmentIndex == 1)
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func excludeHistoryAction(_ sender: Any) {
        scorecard.overrideSettings.excludeHistory = (excludeHistorySelection.selectedSegmentIndex == 0)
        excludeChanged()
        self.enableButtons()
    }
    
    @objc func excludeStatsAction(_ sender: Any) {
        scorecard.overrideSettings.excludeStats = (excludeStatsSelection.selectedSegmentIndex == 0)
        self.enableButtons()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func cardsChanged() {
        let cards = scorecard.overrideSettings.cards
        let direction = (cards[1] < cards[0] ? "down" : "up")
        var cardString = (cards[1] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Go \(direction) to \(cards[1]) \(cardString)", forSegmentAt: 0)
        cardString = (cards[0] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Return to \(cards[0]) \(cardString)", forSegmentAt: 1)
    }
    
    func excludeChanged() {
        if self.scorecard.overrideSettings.excludeHistory {
            self.scorecard.overrideSettings.excludeStats = true
            self.excludeStatsSelection?.selectedSegmentIndex = 0
        }
        self.excludeStatsSelection?.setEnabled(!self.scorecard.overrideSettings.excludeHistory, forSegmentAt: 1)
    }
    
    func enableButtons() {
        let changed = !(self.scorecard.overrideSettings == self.scorecard.gameSettings)
        self.confirmButton.isHidden = !changed
        self.revertButton.setTitle((!changed || !self.existingOverride ? "Cancel" : "Revert"), for: .normal)
    }
    
    // Mark: - Main instatiation routine =============================================================== -
    
    public func show(completion: (()->())? = nil) {
        let storyboard = UIStoryboard(name: "OverrideViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "OverrideViewController") as! OverrideViewController
        let parentViewController = Utility.getActiveViewController()! as! CustomViewController
        viewController.completion = completion
        viewController.formTitle = title
        viewController.message = message

        viewController.preferredContentSize = CGSize(width: 400, height: 700)

        parentViewController.present(viewController, sourceView: parentViewController.popoverPresentationController?.sourceView ?? parentViewController.view, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override internal func didDismiss() {
        // Reset any changes this time
        if !self.existingOverride {
            self.scorecard.resetOverrideSettings()
        } else {
            self.scorecard.overrideSettings = self.existingSettings
        }
        self.completion?()
    }
            
    private func excludeText(from: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()
        var attributes: [NSAttributedString.Key : Any] = [:]
        attributes[NSAttributedString.Key.foregroundColor] = Palette.text
        attributes[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 17.0, weight: .light)
        attributedString.append(NSAttributedString(string: "Include this game in ", attributes: attributes))
        attributes[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        attributedString.append(NSAttributedString(string: from, attributes: attributes))
        
        return attributedString
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class OverrideTableCell: UITableViewCell {
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var subHeadingLabel: UILabel!
    @IBOutlet weak var cardsLabel: UILabel!
    @IBOutlet weak var cardsSlider: UISlider!
    @IBOutlet weak var cardsValue: UITextField!
    @IBOutlet weak var bounceSelection: UISegmentedControl!
    @IBOutlet weak var excludeSelection: UISegmentedControl!
    @IBOutlet weak var excludeLabel: UILabel!
}


