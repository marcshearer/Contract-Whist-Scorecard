//
//  OverrideViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class OverrideViewController : ScorecardViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {
    
    private enum Options: Int, CaseIterable {
        case saveHistory = 0
        case saveStats = 1
        case subHeading = 2
        case startCards = 3
        case endCards = 4
        case bounce = 5
    }
    
    private var value = 1
    private var skipOptions = 0
    
    // UI elements
    private var cardsSlider: [Int : UISlider] = [:]
    private var cardsValue: [Int : UITextField] = [:]
    private var bounceSelection: UISegmentedControl!
    private var saveStatsSelection: UISegmentedControl!
    private var saveHistorySelection: UISegmentedControl!
    private var existingOverride = false
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var revertButton: UIButton!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var insetPaddingView: InsetPaddingView!
    @IBOutlet private weak var instructionView: UIView!
    @IBOutlet private weak var instructionLabel: UILabel!
    @IBOutlet private weak var titleView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        if Scorecard.settings != Scorecard.game.settings && (Scorecard.game.settings.saveStats || Scorecard.game.settings.saveHistory) {
            // Overriding but still saving stats and history
            var includedIn = ""
            if !Scorecard.game.settings.saveHistory {
                includedIn = "player statistics"
            } else if !Scorecard.game.settings.saveStats {
                includedIn = "game history"
            } else {
                includedIn = "player statistics and game history"
            }
            self.alertDecision("You have changed the settings for the game, but your are still including it in \(includedIn). This might lead to inconsistent data. Are you sure you want to do this?", title: "Warning", okButtonText: "Confirm", okHandler: self.dismiss)
        } else {
            self.dismiss()
        }
    }
    
    @IBAction func revertPressed(_ sender: UIButton) {
        // Disable override
        Scorecard.game.reset()
        self.dismiss()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        ScorecardUI.roundCorners(view)
        
        self.existingOverride = (Scorecard.game.settings != Scorecard.settings)
        
        self.skipOptions = (Scorecard.settings.saveHistory ? 0 : 2)
        
        self.revertButton.setTitleColor(Palette.banner.text, for: .normal)
        self.confirmButton.setTitleColor(Palette.banner.text, for: .normal)

        self.enableButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        Scorecard.shared.reCenterPopup(self)
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if Scorecard.settings.saveHistory {
            return Options.allCases.count
        } else {
            return Options.allCases.count - self.skipOptions
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        if let option = Options(rawValue: indexPath.row + skipOptions) {
            switch option {
            case .saveHistory, .saveStats:
                height = 80.0
            case .subHeading:
                height = 80.0
            case .startCards, .endCards:
                height = 32.0
            case .bounce:
                height = 55.0
            }
        }
        return height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: OverrideTableCell!
        
        if let option = Options(rawValue: indexPath.row + skipOptions) {
            switch option {
            case .saveHistory:
                cell = tableView.dequeueReusableCell(withIdentifier: "Save", for: indexPath) as? OverrideTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)

                cell.saveLabel.attributedText = self.includeText(from: "History")
                cell.saveSelection.addTarget(self, action: #selector(OverrideViewController.saveHistoryAction(_:)), for: UIControl.Event.valueChanged)
                cell.saveSelection.selectedSegmentIndex = (Scorecard.game.settings.saveHistory ? 1 : 0)
                self.saveHistorySelection = cell.saveSelection
                self.saveChanged()
                
            case .saveStats:
                cell = tableView.dequeueReusableCell(withIdentifier: "Save", for: indexPath) as? OverrideTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)

                cell.saveLabel.attributedText = self.includeText(from: "Statistics")
                cell.saveSelection.addTarget(self, action: #selector(OverrideViewController.saveStatsAction(_:)), for: UIControl.Event.valueChanged)
                cell.saveSelection.selectedSegmentIndex = (Scorecard.game.settings.saveStats ? 1 : 0)
                self.saveStatsSelection = cell.saveSelection
                
            case .subHeading:
                cell = tableView.dequeueReusableCell(withIdentifier: "Sub Heading", for: indexPath) as? OverrideTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)

                cell.subHeadingLabel.text = "Number of cards in hands"
                
            case .startCards, .endCards:
                let index = (option == .startCards ? 0 : 1)
                cell = tableView.dequeueReusableCell(withIdentifier: "Cards", for: indexPath) as? OverrideTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)

                cell.cardsLabel.text = (index == 0 ? "Start:" : "End:")
                cell.cardsSlider.tag = index
                cell.cardsSlider.addTarget(self, action: #selector(OverrideViewController.cardsSliderAction(_:)), for: UIControl.Event.valueChanged)
                cell.cardsSlider.value = Float(Scorecard.game.settings.cards[index])
                cell.cardsValue.text = "\(Scorecard.game.settings.cards[index])"
                self.cardsSlider[index] = cell.cardsSlider
                self.cardsValue[index] = cell.cardsValue
                
            case .bounce:
                cell = tableView.dequeueReusableCell(withIdentifier: "Bounce", for: indexPath) as? OverrideTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)

                cell.bounceSelection.addTarget(self, action: #selector(OverrideViewController.bounceAction(_:)), for: UIControl.Event.valueChanged)
                cell.bounceSelection.selectedSegmentIndex = (Scorecard.game.settings.bounceNumberCards ? 1 : 0)
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
        Scorecard.game.settings.cards[index] = Int(cardsSlider[index]!.value)
        cardsValue[index]!.text = "\(Scorecard.game.settings.cards[index])"
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func bounceAction(_ sender: Any) {
        Scorecard.game.settings.bounceNumberCards = (bounceSelection.selectedSegmentIndex == 1)
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func saveHistoryAction(_ sender: Any) {
        Scorecard.game.settings.saveHistory = (saveHistorySelection.selectedSegmentIndex == 1)
        saveChanged()
        self.enableButtons()
    }
    
    @objc func saveStatsAction(_ sender: Any) {
        Scorecard.game.settings.saveStats = (saveStatsSelection.selectedSegmentIndex == 1)
        self.enableButtons()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func cardsChanged() {
        let cards = Scorecard.game.settings.cards
        let direction = (cards[1] < cards[0] ? "down" : "up")
        var cardString = (cards[1] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Go \(direction) to \(cards[1]) \(cardString)", forSegmentAt: 0)
        cardString = (cards[0] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Return to \(cards[0]) \(cardString)", forSegmentAt: 1)
    }
    
    func saveChanged() {
        if Scorecard.game.settings.saveHistory {
            // Switched history back on - location should follow it
            Scorecard.game.settings.saveLocation = Scorecard.settings.saveLocation
        } else {
            // Switched history off - location and stats can't be saved
            Scorecard.game.settings.saveLocation = false
            Scorecard.game.settings.saveStats = false
            self.saveStatsSelection?.selectedSegmentIndex = 0
        }
        self.saveStatsSelection?.setEnabled(Scorecard.game.settings.saveHistory, forSegmentAt: 1)
    }
    
    func enableButtons() {
        let changed = (Scorecard.settings != Scorecard.game.settings)
        self.confirmButton.isHidden = !changed
        self.revertButton.setTitle((changed && self.existingOverride ? "Revert" : "Cancel"), for: .normal)
    }
    
    // Mark: - Main instatiation routine =============================================================== -
    
    public static func show(from parentViewController: ScorecardViewController, appController: ScorecardAppController? = nil) -> OverrideViewController? {
        
        let storyboard = UIStoryboard(name: "OverrideViewController", bundle: nil)
        
        let viewController = storyboard.instantiateViewController(withIdentifier: "OverrideViewController") as! OverrideViewController
        
        viewController.preferredContentSize = CGSize(width: 400, height: 700)
        viewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        parentViewController.present(viewController, appController: appController, sourceView: parentViewController.popoverPresentationController?.sourceView ?? parentViewController.view, animated: true, completion: nil)
        
        return viewController
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
         
    private func includeText(from: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()
        var attributes: [NSAttributedString.Key : Any] = [:]
        attributes[NSAttributedString.Key.foregroundColor] = Palette.normal.text
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
    @IBOutlet weak var saveSelection: UISegmentedControl!
    @IBOutlet weak var saveLabel: UILabel!
}

extension OverrideViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bannerPaddingView.bannerColor = Palette.banner.background
        self.insetPaddingView.backgroundColor = Palette.normal.background
        self.insetPaddingView.bannerColor = Palette.normal.background
        self.instructionLabel.textColor = Palette.banner.text
        self.instructionView.backgroundColor = Palette.banner.background
        self.titleLabel.textColor = Palette.banner.text
        self.titleView.backgroundColor = Palette.banner.background
        self.view.backgroundColor = Palette.normal.background
    }

    private func defaultCellColors(cell: OverrideTableCell) {
        switch cell.reuseIdentifier {
        case "Bounce":
            cell.bounceSelection.tintColor = Palette.segmentedControls.background
        case "Cards":
            cell.cardsLabel.textColor = Palette.normal.text
            cell.cardsSlider.minimumTrackTintColor = Palette.segmentedControls.background
            cell.cardsSlider.thumbTintColor = Palette.segmentedControls.background
            cell.cardsValue.textColor = Palette.normal.text
        case "Save":
            cell.saveLabel.textColor = Palette.normal.text
        case "Sub Heading":
            cell.subHeadingLabel.textColor = Palette.normal.text
        default:
            break
        }
    }

}

