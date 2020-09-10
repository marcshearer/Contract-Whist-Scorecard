//
//  AlertViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class AlertViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    
    private var okHandler: (()->())?
    private var cancelHandler: (()->())?
    private var otherHandler: (()->())?
    private var messageText: String?
    private var titleText: String?
    private var okButtonText: String?
    private var otherButtonText: String?
    private var cancelButtonText: String?
    private let separatorWidth: CGFloat = 1.0
    private var firstTime = true
    private var rotated = false
    private var sourceView: UIView?
    
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var okButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var otherButton: UIButton!
    @IBOutlet private weak var cancelButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var otherButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var otherSeparatorWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cancelSeparatorWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var separators: [UIView]!
    
    @IBAction func okPressed(_ sender: UIButton) {
        self.dismiss(animated: false) {
            self.okHandler?()
        }
    }

    @IBAction func otherPressed(_ sender: UIButton) {
        self.dismiss(animated: false) {
            self.otherHandler?()
        }
    }

    @IBAction func cancelPressed(_ sender: UIButton) {
        self.dismiss(animated: false) {
            self.cancelHandler?()
        }
    }
    
    internal override func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel.text = titleText
        self.messageLabel.text = messageText
        self.okButton.setTitle(okButtonText, for: .normal)
        self.otherButton.setTitle(otherButtonText ?? "", for: .normal)
        self.cancelButton.setTitle(cancelButtonText ?? "", for: .normal)
        
        self.setDefaultColors()
    }
    
    internal override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.view.setNeedsLayout()
    }
    
    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.rotated {
            if let sourceView = self.sourceView {
                self.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sourceView.frame.width / 2, y: sourceView.frame.height / 2), size: CGSize())
            }
            self.rotated = false
        }
       
        if self.firstTime {
            let (_, buttonWidth) = self.setupWidths()
            
            if self.cancelButtonText != nil {
                self.cancelButtonWidthConstraint.constant = buttonWidth
            } else {
                self.cancelButtonWidthConstraint.constant = 0
                self.cancelButton.isHidden = true
            }
            if self.otherButtonText != nil {
                self.otherButtonWidthConstraint.constant = buttonWidth
            } else {
                self.otherButtonWidthConstraint.constant = 0
                self.otherButton.isHidden = true
            }
            self.otherSeparatorWidthConstraint.constant = (self.otherButtonText != nil ? 1.0 : 0.0)
            self.cancelSeparatorWidthConstraint.constant = (self.cancelButtonText != nil ? 1.0 : 0.0)
            
            self.firstTime = false
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    private func setDefaultColors() {
        self.view.backgroundColor = Palette.buttonFace.background
        self.messageLabel.textColor = Palette.buttonFace.text
        self.separators.forEach{(separator) in separator.backgroundColor = Palette.separator.background}
    }
    
    private func setupWidths() -> (CGFloat, CGFloat) {
        var buttons = 1
        if otherButtonText != nil { buttons += 1 }
        if cancelButtonText != nil { buttons += 1 }
        let width = buttons <= 1 ? 270 : CGFloat(buttons) * 135
        let buttonWidth: CGFloat = (width - (CGFloat(buttons - 1) * self.separatorWidth)) / CGFloat(buttons)
        return (width, buttonWidth)
    }
    
    
    public static func show(from parentViewController: UIViewController, _ message: String, title: String = "Warning", okButtonText: String = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String? = nil, cancelHandler: (() -> ())? = nil) {
        
        let storyboard = UIStoryboard(name: "AlertViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as! AlertViewController
            
        viewController.messageText = message
        viewController.titleText = title
        viewController.okButtonText = okButtonText
        viewController.okHandler = okHandler
        viewController.cancelButtonText = cancelButtonText
        viewController.cancelHandler = cancelHandler
        viewController.otherButtonText = otherButtonText
        viewController.otherHandler = otherHandler
        
        let (width, _) = viewController.setupWidths()
        let height = AlertViewController.textHeight(width: width - 16, font: UIFont.systemFont(ofSize: 14.0), text: message ) + 107
        
        let sourceView = parentViewController.view
        let sourceRect = CGRect(origin: CGPoint(x: sourceView!.frame.width / 2, y: sourceView!.frame.height / 2), size: CGSize())
        let popoverSize = CGSize(width: width, height: height)
        
        viewController.sourceView = sourceView
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.preferredContentSize = popoverSize
        viewController.popoverPresentationController?.sourceView = sourceView
        viewController.popoverPresentationController?.sourceRect = sourceRect
        viewController.popoverPresentationController?.delegate = viewController
        viewController.isModalInPopover = true
        
        parentViewController.present(viewController, animated: false)
    }
    
    private static func textHeight(width: CGFloat, font: UIFont, text: String) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
        label.numberOfLines = 0
        label.font = font
        label.text = text
        label.sizeToFit()
        return label.frame.height
    }
    
}
