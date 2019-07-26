//
//  SlideOutButtonView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 26/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class SlideOutButtonView: UIView {

    @IBInspectable var title: String!
    @IBInspectable var buttonFillColor: UIColor!
    @IBInspectable var buttonStrokeColor: UIColor!
    @IBInspectable var buttonTextColor: UIColor!
    @IBInspectable var buttonWidth: CGFloat = 0.0
    @IBInspectable var viewBackgroundColor: UIColor!
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var button: AngledButton!
    @IBOutlet weak var toolbarBottomConstraint: NSLayoutConstraint!
    
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadSlideButtonView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadSlideButtonView()
        
    }
    
    private func loadSlideButtonView() {
        Bundle.main.loadNibNamed("ImageButton", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.buttonFillColor = Palette.darkHighlight
        self.buttonStrokeColor = Palette.darkHighlightText
        self.buttonTextColor = Palette.darkHighlightText
        self.viewBackgroundColor = UIColor.clear
        
        self.buttonWidth = self.title.size(withAttributes: [NSAttributedString.Key.font: self.button.titleLabel!.font!]).width + 20.0
        let leadingConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .leading, relatedBy: .equal, toItem: self.contentView.superview!, attribute: .leading, multiplier: 1.0, constant: 0.0)
        self.contentView.superview!.addConstraint(leadingConstraint)
        
        let trailingConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .trailing, relatedBy: .equal, toItem: self.contentView.superview!, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        self.contentView.superview!.addConstraint(trailingConstraint)
        
        let topConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .top, relatedBy: .equal, toItem: self.contentView.superview!.safeAreaLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: -44.0)
        self.contentView.superview!.addConstraint(topConstraint)
        
        let bottomConstraint = NSLayoutConstraint(item: self.contentView as Any, attribute: .top, relatedBy: .equal, toItem: self.contentView.superview!, attribute: .bottom, multiplier: 1.0, constant: -44.0)
        self.contentView.superview!.addConstraint(bottomConstraint)
        
    }
    
    override func layoutSubviews() {
        self.button.fillColor = self.buttonFillColor
        self.button.strokeColor = self.buttonStrokeColor
        self.button.normalTextColor = self.buttonTextColor
        self.button.normalAlpha = 1.0
        self.button.normalBackgroundColor = UIColor.clear
        self.button.setTitle(self.title)
        self.toolbar.backgroundColor = self.viewBackgroundColor
    }
    
    private func showToolbar(_ isHidden: Bool) {
        let toolbarBottomOffset: CGFloat = -44 + (self.superview!.safeAreaInsets.bottom * 0.40)
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
