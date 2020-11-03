//
//  AlertViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum AlertViewButton {
    case ok
    case cancel
    case other
}

class AlertViewController: UIViewController {
    
    private var okHandler: (()->())?
    private var cancelHandler: (()->())?
    private var otherHandler: (()->())?
    private var messageText: String?
    private var titleText: String?
    private var extraHeight: CGFloat = 0
    private var okButtonText: String?
    private var otherButtonText: String?
    private var cancelButtonText: String?
    private let separatorWidth: CGFloat = 1.0
    private var firstTime = true
    private var rotated = false
    private var sourceView: UIView?
    private var activityIndicator: UIActivityIndicatorView?
    
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var buttonView: UIView!
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
            self.okButton.isHidden = self.okButtonText == nil
            self.separators.forEach{ (separator) in separator.isHidden = buttonWidth == 0}
            self.otherSeparatorWidthConstraint.constant = (self.otherButtonText != nil ? 1.0 : 0.0)
            self.cancelSeparatorWidthConstraint.constant = (self.cancelButtonText != nil ? 1.0 : 0.0)
            
            self.firstTime = false
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
      // MARK: - Public interface ======================================================================== -
    
    private func setDefaultColors() {
        self.view.backgroundColor = Palette.buttonFace.background
        self.messageLabel.textColor = Palette.buttonFace.text
        self.separators.forEach{(separator) in separator.backgroundColor = Palette.separator.background}
    }
    
    public func activityIndicator(isHidden: Bool, offset: CGFloat = 0) {
        if !isHidden {
            if self.activityIndicator == nil {
                let frame = CGRect(x: 0, y: offset * 2, width: self.view.frame.width, height: self.view.frame.height - (offset * 2))
                self.activityIndicator = UIActivityIndicatorView(frame: frame)
                self.activityIndicator?.style = UIActivityIndicatorView.Style.large
                self.activityIndicator?.color = UIColor.black
                self.activityIndicator?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.view.addSubview(self.activityIndicator!)
                self.activityIndicator?.isUserInteractionEnabled = true
            }
            self.activityIndicator?.startAnimating()
        } else {
            self.activityIndicator?.stopAnimating()
        }
    }
    
    public func set(message: String) {
        self.messageText = message
        self.messageLabel.text = message
    }
    
    public func set(button: AlertViewButton, text: String? = nil) {
        switch button {
        case .ok:
            self.okButtonText = text
            self.okButton.setTitle(text, for: .normal)
        case .cancel:
            self.cancelButtonText = text
            self.cancelButton.setTitle(text, for: .normal)
        case .other:
            self.otherButtonText = text
            self.otherButton.setTitle(text, for: .normal)
        }
        self.firstTime = true
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    @discardableResult public static func show(from parentViewController: UIViewController, _ message: String, title: String = "Warning", extraHeight: CGFloat = 0.0, okButtonText: String? = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String? = nil, cancelHandler: (() -> ())? = nil) -> AlertViewController {
        
        let storyboard = UIStoryboard(name: "AlertViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as! AlertViewController
            
        viewController.messageText = message
        viewController.titleText = title
        viewController.extraHeight = extraHeight
        viewController.okButtonText = okButtonText
        viewController.okHandler = okHandler
        viewController.cancelButtonText = cancelButtonText
        viewController.cancelHandler = cancelHandler
        viewController.otherButtonText = otherButtonText
        viewController.otherHandler = otherHandler
        
        let (width, _) = viewController.setupWidths()
        let height = message.labelHeight(width: width - 16, font: UIFont.systemFont(ofSize: 14.0)) + extraHeight + 100
        
        let sourceView = parentViewController.view
        let sourceRect = CGRect(origin: CGPoint(x: sourceView!.frame.width / 2, y: sourceView!.frame.height / 2), size: CGSize())
        let popoverSize = CGSize(width: width, height: height)
        
        viewController.sourceView = sourceView
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.preferredContentSize = popoverSize
        viewController.popoverPresentationController?.sourceView = sourceView
        viewController.popoverPresentationController?.sourceRect = sourceRect
        viewController.isModalInPopover = true
        
        parentViewController.present(viewController, animated: false)
        
        return viewController
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setupWidths() -> (CGFloat, CGFloat) {
        var buttons = 0
        if okButtonText != nil { buttons += 1 }
        if otherButtonText != nil { buttons += 1 }
        if cancelButtonText != nil { buttons += 1 }
        let width = buttons <= 1 ? 270 : CGFloat(buttons) * 135
        let buttonWidth: CGFloat = (buttons == 0 ? 0 : (width - (CGFloat(buttons - 1) * self.separatorWidth)) / CGFloat(buttons))
        return (width, buttonWidth)
    }
    
    
}
