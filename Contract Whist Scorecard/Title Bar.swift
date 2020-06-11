//
//  Title Bar.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class TitleBar: UIView {
 
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
    
    @IBOutlet weak public var delegate: ButtonDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    
    
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
    
    public func set(topRounded: Bool? = nil, bottomRounded: Bool? = nil) {
        self.topRounded = topRounded ?? self.topRounded
        self.bottomRounded = bottomRounded ?? self.bottomRounded
        self.setNeedsLayout()
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
        self.backgroundColor = UIColor.clear
        self.contentView.backgroundColor = self.faceColor
        self.titleLabel.text = self.title
        self.titleLabel.textColor = self.textColor
        
        // Round corners
        if self.cornerRadius != 0.0 {
            self.contentView.roundCorners(cornerRadius: self.cornerRadius, topRounded: self.topRounded, bottomRounded: self.bottomRounded)
        }
        
        // Add shadow
        if self.shadowSize != CGSize() {
            self.addShadow(shadowSize: self.shadowSize, shadowColor: self.shadowColor, shadowOpacity: self.shadowOpacity, shadowRadius: self.shadowRadius)
        }
    }
}
