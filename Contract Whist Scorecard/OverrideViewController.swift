//
//  OverrideViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class OverrideViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {
    
    private let scorecard = Scorecard.shared
    
    var message: String!
    var formTitle: String!
    var value = 1
    var completion: (()->())!
    
    let instructionSection = 0
    let cardsSection = 1
    let excludeSection = 2
    
    let startSliderRow = 0
    let endSliderRow = 1
    let bounceRow = 2
    
    let excludeHistoryRow = 0
    let excludeStatsRow = 1

    // UI elements
    private var cardsSlider: [Int : UISlider] = [:]
    private var cardsValue: [Int : UITextField] = [:]
    private var bounceSelection: UISegmentedControl!
    private var excludeStatsSelection: UISegmentedControl!
    private var excludeHistorySelection: UISegmentedControl!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var confirmButton: RoundedButton!
    
    // MARK: - IB Actions ============================================================================== -
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.completion()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        // Disable override
        self.scorecard.resetOverrideSettings()
        self.completion()
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ScorecardUI.roundCorners(view)
        
        if !self.scorecard.overrideSelected {
            self.scorecard.overrideCards = self.scorecard.settingCards
            self.scorecard.overrideBounceNumberCards = self.scorecard.settingBounceNumberCards
            self.scorecard.overrideExcludeStats = true
            self.scorecard.overrideExcludeHistory = false
            self.scorecard.overrideSelected = true
        }
        
        self.confirmButton.normalBackgroundColor = Palette.banner
        self.confirmButton.normalTextColor = Palette.bannerText
        self.confirmButton.normalAlpha = 1.0
        self.confirmButton.disabledBackgroundColor = Palette.banner
        self.confirmButton.disabledTextColor = Palette.bannerText
        self.confirmButton.disabledAlpha = 0.2
        
        self.enableButtons()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return (self.scorecard.settingSaveHistory ? 3 : 2)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case instructionSection:
            return 1
        case cardsSection:
            return 3
        case excludeSection:
            return 2
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case instructionSection:
            return 120
        case cardsSection:
            return 50
        case excludeSection:
            return 50
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: OverrideTableCell!
        
        switch indexPath.section {
        case instructionSection:
            cell = tableView.dequeueReusableCell(withIdentifier: "Instructions Cell", for: indexPath) as? OverrideTableCell
            cell.instructionLabel.text = "You can override the number of cards/deals for the next few games only. The games will still appear in history (if you save it), but you can exclude them from player summary statistics since they might distort average values."
        case cardsSection:
            switch indexPath.row {
            case startSliderRow, endSliderRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Number Cards Cell", for: indexPath) as? OverrideTableCell
                let cardsSlider = cell.cardsSlider!
                let cardsValue = cell.cardsValue!
                cardsSlider.tag = indexPath.row
                cardsSlider.addTarget(self, action: #selector(OverrideViewController.cardsSliderAction(_:)), for: UIControl.Event.valueChanged)
                
                // Set number of rounds value and slider
                cell.cardsLabel.text = (indexPath.row == startSliderRow ? "Start:" : "End:")
                cardsValue.text = "\(scorecard.overrideCards[indexPath.row])"
                cardsSlider.value = Float(scorecard.overrideCards[indexPath.row])
                
                // Store controls
                self.cardsSlider[indexPath.row] = cardsSlider
                self.cardsValue[indexPath.row] = cardsValue
            case bounceRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Bounce Cell", for: indexPath) as? OverrideTableCell
                bounceSelection = cell.bounceSelection
                bounceSelection.addTarget(self, action: #selector(OverrideViewController.bounceAction(_:)), for: UIControl.Event.valueChanged)
                cardsChanged()
                
                // Set bounce number of cards selection
                switch scorecard.overrideBounceNumberCards! {
                case true:
                    bounceSelection.selectedSegmentIndex = 1
                default:
                    bounceSelection.selectedSegmentIndex = 0
                }
            default:
                break
            }
        case excludeSection:
            switch indexPath.row {
            case excludeHistoryRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Exclude History Cell", for: indexPath) as? OverrideTableCell
                excludeHistorySelection = cell.excludeHistorySelection
                excludeHistorySelection.addTarget(self, action: #selector(OverrideViewController.excludeHistoryAction(_:)), for: UIControl.Event.valueChanged)
                excludeChanged()
                
                // Set exclude history selection
                switch scorecard.overrideExcludeHistory! {
                case true:
                    excludeHistorySelection.selectedSegmentIndex = 0
                default:
                    excludeHistorySelection.selectedSegmentIndex = 1
                }
            case excludeStatsRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Exclude Stats Cell", for: indexPath) as? OverrideTableCell
                excludeStatsSelection = cell.excludeStatsSelection
                excludeStatsSelection.addTarget(self, action: #selector(OverrideViewController.excludeStatsAction(_:)), for: UIControl.Event.valueChanged)
                
                // Set exclude stats selection
                switch scorecard.overrideExcludeStats! {
                case true:
                    excludeStatsSelection.selectedSegmentIndex = 0
                default:
                    excludeStatsSelection.selectedSegmentIndex = 1
                }
                
            default:
                break
            }
        default:
            break
        }
        
        return cell as UITableViewCell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == instructionSection {
            return 0
        } else {
            return 30
        }
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        switch section {
        case instructionSection:
            return nil
        case cardsSection:
            return "Number of cards in hands"
        case excludeSection:
            return "Exclude from history/statistics"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        Palette.sectionHeadingStyle(view: header.backgroundView!)
        header.textLabel!.textColor = Palette.sectionHeadingText
        header.textLabel!.font = UIFont.boldSystemFont(ofSize: 18.0)
    }

    // MARK: - Action Handlers ========================================================================= -
    
    @objc internal func cardsSliderAction(_ sender: UISlider) {
        let index = sender.tag
        scorecard.overrideCards[index] = Int(cardsSlider[index]!.value)
        cardsValue[index]!.text = "\(scorecard.overrideCards[index])"
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func bounceAction(_ sender: Any) {
        switch bounceSelection.selectedSegmentIndex {
        case 0:
            scorecard.overrideBounceNumberCards = false
        default:
            scorecard.overrideBounceNumberCards = true
        }
        cardsChanged()
        self.enableButtons()
    }
    
    @objc func excludeHistoryAction(_ sender: Any) {
        switch excludeHistorySelection.selectedSegmentIndex {
        case 0:
            scorecard.overrideExcludeHistory = true
        default:
            scorecard.overrideExcludeHistory = false
        }
        excludeChanged()
        self.enableButtons()
    }
    
    @objc func excludeStatsAction(_ sender: Any) {
        switch excludeStatsSelection.selectedSegmentIndex {
        case 0:
            scorecard.overrideExcludeStats = true
        default:
            scorecard.overrideExcludeStats = false
        }
        self.enableButtons()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func cardsChanged() {
        let cards = scorecard.overrideCards!
        let direction = (cards[1] < cards[0] ? "down" : "up")
        var cardString = (cards[1] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Go \(direction) to \(cards[1]) \(cardString)", forSegmentAt: 0)
        cardString = (cards[0] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Return to \(cards[0]) \(cardString)", forSegmentAt: 1)
    }
    
    func excludeChanged() {
        if self.scorecard.overrideExcludeHistory {
            self.scorecard.overrideExcludeStats = true
            self.excludeStatsSelection?.selectedSegmentIndex = 0
        }
        self.excludeStatsSelection?.isEnabled = !self.scorecard.overrideExcludeHistory
    }
    
    func enableButtons() {
        let enabled = self.scorecard.checkOverride()
        self.confirmButton.isEnabled(enabled)
    }
    
    // Mark: - Main instatiation routine =============================================================== -
    
    func show(completion: (()->())? = nil) {
        let storyboard = UIStoryboard(name: "OverrideViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "OverrideViewController") as! OverrideViewController
        let parentViewController = Utility.getActiveViewController()!
        viewController.completion = completion
        viewController.formTitle = title
        viewController.message = message

        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.delegate = self
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.popoverPresentationController?.sourceView = parentViewController.view
        viewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height/2, width: 0 ,height: 0)
        viewController.preferredContentSize = CGSize(width: 400, height: 500)

        parentViewController.present(viewController, animated: true, completion: nil)
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class OverrideTableCell: UITableViewCell {
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var cardsLabel: UILabel!
    @IBOutlet weak var cardsSlider: UISlider!
    @IBOutlet weak var cardsValue: UITextField!
    @IBOutlet weak var bounceSelection: UISegmentedControl!
    @IBOutlet weak var excludeStatsSelection: UISegmentedControl!
    @IBOutlet weak var excludeHistorySelection: UISegmentedControl!
}


