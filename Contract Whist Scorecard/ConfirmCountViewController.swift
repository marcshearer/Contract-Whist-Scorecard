//
//  ConfirmCountViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmCountViewController : CustomViewController, UIPopoverPresentationControllerDelegate {
    
    var message: String!
    var formTitle: String!
    var value = 1
    var minimumValue: Int?
    var maximumValue: Int?
    var backColor = ScorecardUI.totalColor
    var confirmHandler: ((Int)->())!
    
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelMessage: UILabel!
    @IBOutlet weak var textFieldCount: UITextField!
    @IBOutlet weak var stepperCount: UIStepper!
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: {
            self.confirmHandler(self.value)
        })
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        value = Int(self.stepperCount.value)
        self.textFieldCount.text = "\(value)"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.labelTitle.text = self.formTitle
        self.labelMessage.text = self.message
        self.textFieldCount.text = "\(value)"
        self.stepperCount.value = Double(value)
        if self.minimumValue != nil {
            self.stepperCount.minimumValue = Double(self.minimumValue!)
        }
        if self.maximumValue != nil {
            self.stepperCount.maximumValue = Double(self.maximumValue!)
        }
        view.backgroundColor = self.backColor
        ScorecardUI.roundCorners(view)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // return UIModalPresentationStyle.FullScreen
        return UIModalPresentationStyle.none
    }
    
}

class ConfirmCount {
    
    func show(title: String, message: String, defaultValue: Int = 1, minimumValue: Int? = nil, maximumValue: Int? = nil, height: Int = 260, backColor: UIColor = ScorecardUI.totalColor, handler: @escaping ((Int)->())) {
        let storyboard = UIStoryboard(name: "ConfirmCountViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ConfirmCountViewController") as! ConfirmCountViewController
    
        let parentViewController = Utility.getActiveViewController()!
        viewController.minimumValue = minimumValue
        viewController.maximumValue = maximumValue
        viewController.formTitle = title
        viewController.message = message
        viewController.value = defaultValue
        viewController.confirmHandler = handler
        viewController.backColor = backColor
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.delegate = viewController
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.popoverPresentationController?.sourceView = parentViewController.view
        viewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height/2, width: 0 ,height: 0)
        viewController.preferredContentSize = CGSize(width: 280, height: height)
        parentViewController.present(viewController, animated: true, completion: nil)
    }
}

