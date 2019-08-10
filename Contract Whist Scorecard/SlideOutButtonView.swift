//
//  SlideOutButtonView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 26/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol SlideOutButtonDelegate {
    func slideOutButtonPressed(_ sender: SlideOutButtonView)
}

class SlideOutButtonView: UIView {

    @IBInspectable var title: String!
    @IBInspectable var buttonFillColor: UIColor!
    @IBInspectable var buttonStrokeColor: UIColor!
    @IBInspectable var buttonTextColor: UIColor!
    @IBInspectable var viewBackgroundColor: UIColor!
    
    @IBOutlet public var delegate: SlideOutButtonDelegate?
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var toolbar: UIView!
    @IBOutlet private weak var button: AngledButton!
    @IBOutlet private weak var toolbarBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var buttonWidthConstraint: NSLayoutConstraint!
    
    private var _isHidden: Bool = true
    override var isHidden: Bool {
        get {
            return self._isHidden
        }
        set(newValue) {
            self._isHidden = newValue
            self.showToolbar(newValue)
        }
        
    }
    
    public var isEnabled: Bool {
        get {
            return self.button.isEnabled
        }
        set(newValue) {
            self.button.isEnabled = newValue
        }
    }
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        self.delegate?.slideOutButtonPressed(self)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadSlideButtonView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadSlideButtonView()
        
    }
    
    private func loadSlideButtonView() {
        Bundle.main.loadNibNamed("SlideOutButtonView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.buttonFillColor = Palette.darkHighlight
        self.buttonStrokeColor = Palette.darkHighlightText
        self.buttonTextColor = Palette.darkHighlightText
        self.viewBackgroundColor = UIColor.clear
    }
    
    override func didMoveToSuperview() {
        
        // Setup vertical constraints on superview (assumed to be main view)
        
        let topConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .top, relatedBy: .equal, toItem: self.superview!, attribute: .bottom, multiplier: 1.0, constant: -44.0)
        self.superview!.addConstraint(topConstraint)
        
        let bottomConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .bottom, relatedBy: .equal, toItem: self.superview!, attribute: .bottom, multiplier: 1.0, constant: 88.0)
        self.superview!.addConstraint(bottomConstraint)
    }
    
    private func showToolbar(_ isHidden: Bool, animated: Bool = true) {
        if self.superview != nil {
            self.button.fillColor = self.buttonFillColor
            self.button.strokeColor = self.buttonStrokeColor
            self.button.normalTextColor = self.buttonTextColor
            self.button.normalAlpha = 1.0
            self.button.normalBackgroundColor = UIColor.clear
            self.button.setTitle(self.title)
            self.button.isEnabled(true)
            self.toolbar.backgroundColor = self.viewBackgroundColor
            self.contentView.backgroundColor = UIColor.clear
            self.backgroundColor = UIColor.clear
            self.layoutIfNeeded()
            
            // Set button width
            let buttonWidth = max(self.superview!.frame.width * 0.33, self.title.size(withAttributes: [NSAttributedString.Key.font: self.button.titleLabel!.font!]).width + 20.0)
            self.buttonWidthConstraint?.constant = buttonWidth
            self.button.frame = CGRect(x: (self.toolbar.frame.width - buttonWidth) / 2.0, y: self.button.frame.minY, width: buttonWidth, height: self.button.frame.height)
            self.contentView.superview!.bringSubviewToFront(self.contentView)
            let toolbarBottomOffset: CGFloat = (isHidden ? 0 : 88.0 + (self.contentView.superview!.safeAreaInsets.bottom * 0.4))
            if toolbarBottomOffset != self.toolbarBottomConstraint.constant {
                if animated {
                    Utility.animate(duration: 0.3) {
                        self.toolbarBottomConstraint.constant = toolbarBottomOffset
                    }
                } else {
                    self.toolbarBottomConstraint.constant = toolbarBottomOffset
                }
            }
        }
    }

}
