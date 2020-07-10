//
//  ConfirmPlayed.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmPlayedViewController : ScorecardViewController, UIPopoverPresentationControllerDelegate {
    
    private var message: String!
    private var formTitle: String!
    private var content: UIView!
    private var confirmText: String?
    private var cancelText: String?
    private var backgroundColor: UIColor?
    private var bannerColor: UIColor?
    private var bannerTextColor: UIColor?
    private var buttonColor: UIColor?
    private var buttonTextColor: UIColor?
    private var confirmHandler: (()->())?
    private var cancelHandler: (()->())?
    private var blurredBackgroundView: UIView!
    static private var parentViewController: UIViewController!
    static private var sourceView: UIView!
    static private var preferredHeight: CGFloat!
    static private var offsets: (portrait: CGFloat?, landscape: CGFloat?) = (0.0, 0.0)

    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    
    @IBAction func confirmPressed(_ sender: UIButton) {
        self.removeBackgroundView()
        self.dismiss(completion: self.confirmHandler)
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.removeBackgroundView()
        self.dismiss(completion: self.cancelHandler)
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Utility.mainThread {
            // Have to wrap this in main thread for it to work!! Apparently fixed in iOS 13
            self.contentView.backgroundColor = self.backgroundColor ?? Palette.background
            self.labelTitle.backgroundColor = self.bannerColor ?? Palette.roomInterior
            self.labelTitle.textColor = self.bannerTextColor ?? Palette.roomInteriorText
            self.confirmButton.backgroundColor = self.buttonColor ?? Palette.roomInterior
            self.confirmButton.setTitleColor(self.buttonTextColor, for: .normal)
            self.cancelButton.backgroundColor = self.buttonColor ?? Palette.roomInterior
            self.cancelButton.setTitleColor(self.buttonTextColor, for: .normal)
        }
        self.view.setNeedsLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Avoid animating
        coordinator.animate(alongsideTransition: nil, completion:
            {_ in
                UIView.setAnimationsEnabled(true)
        })
        UIView.setAnimationsEnabled(false)
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.removeBackgroundView()
        ConfirmPlayedViewController.parentViewController.view.layoutIfNeeded()
        ConfirmPlayedViewController.sourceView.layoutIfNeeded()
        self.overlayBackgroundViews()
        self.reCenterPopup()
        Constraint.anchor(view: self.contentView, control: content, attributes: .centerX, .centerY)
    }
    
    func overlayBackgroundViews() {
        
        self.blurredBackgroundView = UIView(frame: CGRect(origin: CGPoint(), size: ConfirmPlayedViewController.sourceView.frame.size))
        self.blurredBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        ConfirmPlayedViewController.sourceView.addSubview(blurredBackgroundView)
    }
    
    func removeBackgroundView() {
        
        self.blurredBackgroundView?.removeFromSuperview()
    }
    
    class private func yOffset() -> CGFloat {
        var yOffset: CGFloat = 0.0
        if let sourceView = ConfirmPlayedViewController.sourceView {
            let topSpace = (sourceView.frame.height - self.preferredHeight) / 2.0
            if let offset = (ScorecardUI.landscapePhone() ? offsets.landscape : offsets.portrait) {
                yOffset = topSpace * offset
            }
        }
        return yOffset
    }
    
    func reCenterPopup() {

        if let sourceView = ConfirmPlayedViewController.sourceView {
            
            let verticalCenter: CGFloat = sourceView.bounds.midY - ConfirmPlayedViewController.yOffset()
            self.popoverPresentationController?.sourceView = sourceView
            self.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sourceView.bounds.midX, y: verticalCenter), size: CGSize())
        }
    }
    
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    class func show(from parentViewController: ScorecardViewController, appController: ScorecardAppController? = nil, title: String, content: UIView, sourceView: UIView? = nil, confirmText: String? = nil, cancelText: String? = nil, minWidth: CGFloat = 240, minHeight: CGFloat = 200.0, offsets: (portrait: CGFloat?, landscape: CGFloat?) = (0.0, nil), backgroundColor: UIColor? = nil, bannerColor: UIColor? = nil, bannerTextColor: UIColor? = nil, buttonColor: UIColor? = nil, buttonTextColor: UIColor? = nil, confirmHandler: (()->())? = nil, cancelHandler: (()->())? = nil) -> ConfirmPlayedViewController {
        let storyboard = UIStoryboard(name: "ConfirmPlayedViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ConfirmPlayedViewController") as! ConfirmPlayedViewController
        
        ConfirmPlayedViewController.parentViewController = parentViewController
        viewController.formTitle = title
        viewController.content = content
        viewController.confirmText = confirmText
        viewController.cancelText = cancelText
        viewController.backgroundColor = backgroundColor
        viewController.bannerColor = bannerColor
        viewController.bannerTextColor = bannerTextColor
        viewController.buttonColor = buttonColor
        viewController.buttonTextColor = buttonTextColor
        viewController.confirmHandler = confirmHandler
        viewController.cancelHandler = cancelHandler
        let sourceView = sourceView ?? parentViewController.view
        ConfirmPlayedViewController.sourceView = sourceView
        ConfirmPlayedViewController.offsets = offsets
        ConfirmPlayedViewController.preferredHeight = max(minHeight, content.frame.height + 100.0)
        
            
        viewController.modalPresentationStyle = UIModalPresentationStyle.popover
        viewController.popoverPresentationController?.delegate = viewController
        viewController.isModalInPopover = true
        viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        viewController.popoverPresentationController?.sourceView = sourceView
        viewController.preferredContentSize = CGSize(width: max(minWidth, content.frame.width), height: ConfirmPlayedViewController.preferredHeight)
        viewController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sourceView!.bounds.midX, y: sourceView!.bounds.midY - self.yOffset()), size: CGSize())
        
        parentViewController.present(viewController, appController: appController, animated: true)
        
        return viewController
    }
    
    private func dismiss(completion: (()->())? = nil) {
        self.dismiss(animated: true, completion: {
            completion?()
        })
    }
}

