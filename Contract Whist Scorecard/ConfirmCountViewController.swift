//
//  ConfirmCountViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmCountViewController : ScorecardViewController, UIPopoverPresentationControllerDelegate {
    
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
        self.textFieldCount.layer.borderColor = Palette.normal.text.cgColor
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
        
        viewController.minimumValue = minimumValue
        viewController.maximumValue = maximumValue
        viewController.formTitle = title
        viewController.message = message
        viewController.value = defaultValue
        viewController.confirmHandler = handler
        
        let parentViewController = Utility.getActiveViewController()!
        let sourceView = parentViewController.popoverPresentationController?.sourceView ?? parentViewController.view
        let sourceRect = CGRect(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height/2, width: 0 ,height: 0)
        let popoverSize = CGSize(width: 280, height: height)
        
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.preferredContentSize = popoverSize
        viewController.popoverPresentationController?.sourceView = sourceView
        viewController.popoverPresentationController?.sourceRect = sourceRect
        viewController.popoverPresentationController?.delegate = viewController

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
        self.cancelButton.backgroundColor = Palette.normal.background
        self.cancelButton.setTitleColor(Palette.normal.text, for: .normal)
        self.confirmButton.backgroundColor = Palette.normal.background
        self.confirmButton.setTitleColor(Palette.normal.text, for: .normal)
        self.horizontalSeparator.backgroundColor = Palette.separator.background
        self.labelMessage.textColor = Palette.normal.text
        self.labelTitle.backgroundColor = Palette.roomInterior.background
        self.labelTitle.textColor = Palette.roomInterior.text
        self.stepperCount.tintColor = Palette.normal.text
        self.textFieldCount.backgroundColor = Palette.alternate.background
        self.textFieldCount.textColor = Palette.normal.text
        self.verticalSeparator.backgroundColor = Palette.separator.background
        self.view.backgroundColor = Palette.normal.background
    }
}

