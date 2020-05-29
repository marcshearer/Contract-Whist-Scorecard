//
//  ConfirmCountViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmCountViewController : UIViewController, UIPopoverPresentationControllerDelegate {
    
    var message: String!
    var formTitle: String!
    var value = 1
    var minimumValue: Int?
    var maximumValue: Int?
    var confirmHandler: ((Int)->())!
    
    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var labelMessage: UILabel!
    @IBOutlet private weak var textFieldCount: UITextField!
    @IBOutlet private weak var stepperCount: UIStepper!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var verticalSeparator: UIView!
    @IBOutlet private weak var horizontalSeparator: UIView!
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.dismiss(completion: { self.confirmHandler(self.value) })
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        value = Int(self.stepperCount.value)
        self.textFieldCount.text = "\(value)"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up default colors (previously done in storyboard)
        self.defaultViewColors()
        
        self.labelTitle.text = self.formTitle
        self.labelMessage.text = self.message
        self.textFieldCount.text = "\(value)"
        self.textFieldCount.layer.borderColor = Palette.highlightText.cgColor
        self.textFieldCount.layer.borderWidth = 1.0
        self.stepperCount.value = Double(value)
        if self.minimumValue != nil {
            self.stepperCount.minimumValue = Double(self.minimumValue!)
        }
        if self.maximumValue != nil {
            self.stepperCount.maximumValue = Double(self.maximumValue!)
        }
        ScorecardUI.roundCorners(view)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self, ignoreScorepad: true)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // return UIModalPresentationStyle.FullScreen
        return UIModalPresentationStyle.none
    }
    
    static func show(title: String, message: String, defaultValue: Int = 1, minimumValue: Int? = nil, maximumValue: Int? = nil, height: Int = 260, handler: @escaping ((Int)->())) {
        let storyboard = UIStoryboard(name: "ConfirmCountViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ConfirmCountViewController") as! ConfirmCountViewController
    
        let parentViewController = Utility.getActiveViewController()!
        viewController.minimumValue = minimumValue
        viewController.maximumValue = maximumValue
        viewController.formTitle = title
        viewController.message = message
        viewController.value = defaultValue
        viewController.confirmHandler = handler
 
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.delegate = viewController
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.popoverPresentationController?.sourceView = parentViewController.popoverPresentationController?.sourceView ?? parentViewController.view
        viewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height/2, width: 0 ,height: 0)
        viewController.preferredContentSize = CGSize(width: 280, height: height)

        parentViewController.present(viewController, animated: true, completion: nil)
    }
    
    private func dismiss(completion: (()->())? = nil) {
        self.dismiss(animated: true, completion: {
            completion?()
        })
    }
    
}

extension ConfirmCountViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {
        self.cancelButton.backgroundColor = Palette.roomInterior
        self.cancelButton.setTitleColor(Palette.roomInteriorText, for: .normal)
        self.confirmButton.backgroundColor = Palette.roomInterior
        self.confirmButton.setTitleColor(Palette.roomInteriorText, for: .normal)
        self.horizontalSeparator.backgroundColor = Palette.separator
        self.labelMessage.textColor = Palette.highlightText
        self.labelTitle.backgroundColor = Palette.roomInterior
        self.labelTitle.textColor = Palette.roomInteriorText
        self.stepperCount.tintColor = Palette.highlightText
        self.textFieldCount.backgroundColor = Palette.alternateBackground
        self.textFieldCount.textColor = Palette.text
        self.verticalSeparator.backgroundColor = Palette.separator
        self.view.backgroundColor = Palette.background
    }
}

