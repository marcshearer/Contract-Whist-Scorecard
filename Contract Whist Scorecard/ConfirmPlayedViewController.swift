//
//  ConfirmPlayed.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class ConfirmPlayedViewController : ScorecardViewController {
    
    private var message: String!
    private var formTitle: String!
    private var content: UIView!
    private var confirmText: String?
    private var cancelText: String?
    private var titleOffset: CGFloat = 0.0
    private var contentOffset: CGPoint?
    private var backgroundColor: UIColor?
    private var bannerColor: UIColor?
    private var bannerTextColor: UIColor?
    private var buttonColor: UIColor?
    private var buttonTextColor: UIColor?
    private var confirmHandler: (()->())?
    private var cancelHandler: (()->())?
    private var blurredBackgroundView: UIView!
    private var blurredConstraints: [NSLayoutConstraint]!
    private var sourceView: UIView!
    private var parentView: UIView!
    private var preferredHeight: CGFloat!
    private var offsets: (portrait: CGFloat?, landscape: CGFloat?) = (0.0, 0.0)

    @IBOutlet private weak var titleView: UIView!
    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var labelTitleHeightOffset: NSLayoutConstraint!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var confirmButton: UIButton!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var verticalSeparatorView: UIView!
    @IBOutlet private weak var horizontalSeparatorView: UIView!
    
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
        Constraint.anchor(view: self.contentView, control: content, constant: contentOffset?.x ?? 0.0, attributes: .centerX)
        Constraint.anchor(view: self.contentView, control: content, constant: contentOffset?.y ?? 0.0, attributes: .centerY)
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
        self.contentView.backgroundColor = self.backgroundColor ?? Palette.normal.background
        self.titleView.backgroundColor = self.bannerColor ?? Palette.roomInterior.background
        self.labelTitle.textColor = self.bannerTextColor ?? Palette.roomInterior.text
        self.confirmButton.backgroundColor = self.buttonColor ?? Palette.roomInterior.background
        self.confirmButton.setTitleColor(self.buttonTextColor ?? Palette.roomInterior.text, for: .normal)
        self.cancelButton.backgroundColor = self.buttonColor ?? Palette.roomInterior.background
        self.cancelButton.setTitleColor(self.buttonTextColor ?? Palette.roomInterior.text, for: .normal)
        self.horizontalSeparatorView.backgroundColor = self.backgroundColor ?? Palette.normal.background
        self.verticalSeparatorView.backgroundColor = self.backgroundColor ?? Palette.normal.background
        self.overlayBackgroundViews()
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
        self.labelTitleHeightOffset.constant = self.titleOffset
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.removeBackgroundView()
    }
    
    func overlayBackgroundViews() {
        
        self.blurredBackgroundView = UIView()
        self.blurredBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.sourceView.addSubview(self.blurredBackgroundView)
        self.blurredConstraints = Constraint.anchor(view: self.sourceView, control: self.blurredBackgroundView)
    }
    
    func removeBackgroundView() {
        
        if let constraints = self.blurredConstraints {
            self.sourceView.removeConstraints(constraints)
        }
        self.blurredBackgroundView?.removeFromSuperview()
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    class func show(from parentViewController: ScorecardViewController, appController: ScorecardAppController? = nil, title: String, content: UIView, sourceView: UIView? = nil, verticalOffset: CGFloat = 0.5, confirmText: String? = nil, cancelText: String? = nil, minWidth: CGFloat = 240, minHeight: CGFloat = 200.0, titleOffset: CGFloat = 0.0, contentOffset: CGPoint? = nil, backgroundColor: UIColor? = nil, bannerColor: UIColor? = nil, bannerTextColor: UIColor? = nil, buttonColor: UIColor? = nil, buttonTextColor: UIColor? = nil, confirmHandler: (()->())? = nil, cancelHandler: (()->())? = nil) -> ConfirmPlayedViewController {
        let storyboard = UIStoryboard(name: "ConfirmPlayedViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ConfirmPlayedViewController") as! ConfirmPlayedViewController
        
        viewController.parentView = parentViewController.view
        viewController.formTitle = title
        viewController.content = content
        viewController.confirmText = confirmText
        viewController.cancelText = cancelText
        viewController.contentOffset = contentOffset
        viewController.titleOffset = titleOffset
        viewController.backgroundColor = backgroundColor
        viewController.bannerColor = bannerColor
        viewController.bannerTextColor = bannerTextColor
        viewController.buttonColor = buttonColor
        viewController.buttonTextColor = buttonTextColor
        viewController.confirmHandler = confirmHandler
        viewController.cancelHandler = cancelHandler
        let sourceView = sourceView ?? parentViewController.view
        viewController.sourceView = sourceView
        viewController.preferredHeight = max(minHeight, content.frame.height + 100.0)
        viewController.isModalInPopover = true
            
        let popoverSize = CGSize(width: max(minWidth, content.frame.width), height: viewController.preferredHeight)
        
        parentViewController.present(viewController, appController: appController, popoverSize: popoverSize, sourceView: sourceView, verticalOffset: verticalOffset, animated: true)
        
        return viewController
    }
    
    private func dismiss(completion: (()->())? = nil) {
        self.dismiss(animated: true, completion: {
            completion?()
        })
    }
}

