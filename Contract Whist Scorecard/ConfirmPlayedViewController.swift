//
//  ConfirmPlayed.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmPlayedViewController : UIViewController, UIPopoverPresentationControllerDelegate {
    
    private var message: String!
    private var formTitle: String!
    private var content: UIView!
    private var confirmText: String?
    private var cancelText: String?
    private var confirmHandler: (()->())?
    
    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var sourceView: UIView!
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: {
            self.confirmHandler?()
        })
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.labelTitle.text = self.formTitle
        self.contentView.subviews.forEach( { $0.removeFromSuperview() } )
        self.contentView.addSubview(content)
        if let confirmText = self.confirmText {
            self.confirmButton.setTitle(confirmText, for: .normal)
        }
        if let cancelText = self.cancelText {
            self.cancelButton.setTitle(cancelText, for: .normal)
        }
        ScorecardUI.roundCorners(view)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.setNeedsLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Scorecard.shared.reCenterPopup(self, ignoreScorepad: true)
        self.sourceView.layoutIfNeeded()
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Scorecard.shared.reCenterPopup(self, ignoreScorepad: true)
        Constraint.anchor(view: self.contentView, control: content, attributes: .centerX, .centerY)
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        Scorecard.shared.reCenterPopup(self)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // return UIModalPresentationStyle.FullScreen
        return UIModalPresentationStyle.none
    }
    
    class func show(title: String, content: UIView, sourceView: UIView? = nil, confirmText: String? = nil, cancelText: String? = nil, minWidth: CGFloat = 240, minHeight: CGFloat = 200.0, handler: (()->())? = nil) {
        let storyboard = UIStoryboard(name: "ConfirmPlayedViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ConfirmPlayedViewController") as! ConfirmPlayedViewController
        
        let parentViewController = Utility.getActiveViewController()!
        viewController.formTitle = title
        viewController.content = content
        viewController.confirmText = confirmText
        viewController.cancelText = cancelText
        viewController.confirmHandler = handler
        let sourceView = sourceView ?? parentViewController.view
        viewController.sourceView = sourceView
        
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.delegate = viewController
        viewController.isModalInPopover = true
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.popoverPresentationController?.sourceView = sourceView
        viewController.preferredContentSize = CGSize(width: max(minWidth, content.frame.width), height: max(minHeight, content.frame.height + 100.0))
        viewController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sourceView!.bounds.midX, y: sourceView!.bounds.midY), size: CGSize())
        
        parentViewController.present(viewController, animated: true, completion: nil)
    }
}

