//
//  Title Bar.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class TitleBar: UIView {
 
    private var alignment: NSTextAlignment?
    
    @IBInspectable private var title = ""
    @IBInspectable private var topRounded = true
    @IBInspectable private var bottomRounded = false
    @IBInspectable private var cornerRadius: CGFloat = 0.0
    @IBInspectable private var font: UIFont!
    @IBInspectable private var faceColor: UIColor!
    @IBInspectable private var textColor: UIColor!
    @IBInspectable private var shadowSize = CGSize()
    @IBInspectable private var shadowColor: UIColor?
    @IBInspectable private var shadowOpacity: CGFloat = 0.2
    @IBInspectable private var shadowGradient = false
    @IBInspectable private var shadowRadius: CGFloat = 0.0
    @IBInspectable private var labelProportion: CGFloat = 1.0
    @IBInspectable private var transparent: Bool = false
    
    @IBOutlet weak public var delegate: ButtonDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var titleLabelHeight: NSLayoutConstraint!
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadTitleBarView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadTitleBarView()
    }
    
    public func set(title: String) {
        self.title = title
        self.titleLabel.text = title
    }
    
    public func set(faceColor: UIColor) {
        self.faceColor = faceColor
        self.contentView.backgroundColor = faceColor
    }
    
    public func set(shadowColor: UIColor) {
        self.shadowColor = shadowColor
    }
    
    public func set(textColor: UIColor) {
        self.textColor = textColor
        self.titleLabel.textColor = textColor
    }
    
    public func set(font: UIFont) {
        self.font = font
        self.titleLabel.font = font
    }
    
    public func set(labelProportion: CGFloat) {
        self.labelProportion = labelProportion
        self.titleLabelHeight.constant = labelProportion * self.contentView.frame.height
    }
    
    public func set(topRounded: Bool? = nil, bottomRounded: Bool? = nil) {
        self.topRounded = topRounded ?? self.topRounded
        self.bottomRounded =  bottomRounded ?? self.bottomRounded
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    public func set(transparent: Bool, alignment: NSTextAlignment) {
        self.transparent = transparent
        self.alignment = alignment
        if self.font == nil {
            if transparent {
                self.titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
            } else {
                self.titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .light)
            }
        }
        self.layoutSubviews()
    }
    
    private func loadTitleBarView() {
        Bundle.main.loadNibNamed("TitleBar", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(TitleBar.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
        
        self.layoutSubviews()
        self.setNeedsLayout()
    }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.delegate?.buttonPressed(self)
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        self.sendSubviewToBack(self.contentView)
        self.titleLabelHeight.constant = labelProportion * self.contentView.frame.height
        self.backgroundColor = UIColor.clear
        self.contentView.backgroundColor = (transparent ? UIColor.clear : self.faceColor)
        self.titleLabel.text = self.title
        self.titleLabel.textColor = self.textColor
        self.titleLabel.textAlignment = self.alignment ?? .center
        
        // Round corners
        if self.cornerRadius != 0.0 {
            self.contentView.roundCorners(cornerRadius: self.cornerRadius, topRounded: self.topRounded, bottomRounded: self.bottomRounded)
        }
        
        // Add shadow
        if self.shadowSize != CGSize() && !transparent {
            self.addShadow(shadowSize: self.shadowSize, shadowColor: self.shadowColor, shadowOpacity: self.shadowOpacity, shadowRadius: self.shadowRadius)
        } else {
            self.removeShadow()
        }
    }
}
