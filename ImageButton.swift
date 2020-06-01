//
//  ImageButtonView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol ImageButtonDelegate {
    func imageButtonPressed(_ sender: ImageButton)
}

class ImageButton: UIView {
    
    @IBInspectable private var faceColor: UIColor?
    @IBInspectable private var cornerRadius: CGFloat = 0.0
    @IBInspectable private var image: UIImage!
    @IBInspectable private var title: String!
    @IBInspectable private var titleColor: UIColor?
    @IBInspectable private var shadowSize = CGSize()
    @IBInspectable private var shadowColor: UIColor?
    @IBInspectable private var shadowOpacity: CGFloat = 0.0
    @IBInspectable private var shadowRadius: CGFloat = 0.0
    
    @IBInspectable private var message: String?
    @IBInspectable private var messageColor: UIColor?
    
    @IBInspectable private var backgroundImage: UIImage!
    @IBInspectable private var backgroundImageOpacity: CGFloat = 0.0
    
    @IBOutlet weak public var delegate: ImageButtonDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    
    @IBOutlet private weak var topConstraint: NSLayoutConstraint!
    @IBOutlet private weak var imageBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var titleBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var messageHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bottomConstraint: NSLayoutConstraint!
    
    private var shadowView: UIView!
    private var shadowGradientView: UIView!
    private var heightProportion: (top: CGFloat, image: CGFloat, imageBottom: CGFloat, title: CGFloat, titleBottom: CGFloat, message: CGFloat, bottom: CGFloat) =  (0.0, 0.74, 0.04, 0.22, 0.0, 0.0, 0.0)
    
    public var isEnabled: Bool {
        get {
            return self.contentView.isUserInteractionEnabled
        }
        set(newValue) {
            self.contentView.isUserInteractionEnabled = newValue
        }
    }
    
    override var alpha: CGFloat {
        get {
            return self.contentView.alpha
        }
        set(newValue) {
            self.imageView?.alpha = newValue
            self.titleLabel?.alpha = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadImageButtonView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadImageButtonView()
    }
    
    public func set(image: UIImage?) {
        self.image = image
        self.imageView.image = image
    }
    
    public func set(imageTintColor: UIColor) {
        self.imageView.tintColor = imageTintColor
    }
    
    public func set(title: String) {
        self.title = title
        self.titleLabel.text = title
    }
    
    public func set(titleFont: UIFont) {
        self.titleLabel.font = titleFont
    }
    
    public func set(titleColor: UIColor) {
        self.titleColor = titleColor
        self.titleLabel.textColor = titleColor
    }

    public func set(message: String) {
        self.message = message
        self.messageLabel.text = message
    }
    
    public func set(messageFont: UIFont) {
        self.messageLabel.font = messageFont
    }

    public func set(messageColor: UIColor) {
        self.messageColor = messageColor
        self.messageLabel.textColor = messageColor
    }
    
    public func set(textColor: UIColor) {
        self.titleColor = textColor
    }

    public func set(faceColor: UIColor) {
        self.faceColor = faceColor
    }

    public func set(shadowSize: CGSize? = nil, shadowColor: UIColor? = nil, shadowOpacity: CGFloat? = nil, shadowRadius: CGFloat? = nil) {
        self.shadowSize = shadowSize ?? self.shadowSize
        self.shadowColor = shadowColor ?? self.shadowColor
        self.shadowOpacity = shadowOpacity ?? self.shadowOpacity
        self.shadowRadius = shadowRadius ?? self.shadowRadius
    }
    
    public func set(backgroundImage: UIImage?) {
        self.backgroundImage = backgroundImage
        self.backgroundImageView.image = backgroundImage
    }
    
    public func set(backgroundImageOpacity: CGFloat) {
        self.backgroundImageOpacity = backgroundImageOpacity
        self.backgroundImageView.alpha = backgroundImageOpacity
    }
    
    private func loadImageButtonView() {
        Bundle.main.loadNibNamed("ImageButton", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ImageButton.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
        
        self.layoutSubviews()
    }
    
    @objc private func tapSelector(_ sender: Any) {
        self.delegate?.imageButtonPressed(self)
    }
    
    override func layoutSubviews() {
        self.titleLabel.text = self.title
        self.titleLabel.textColor = self.titleColor
        self.imageView.image = self.image
        self.backgroundImageView.image = self.backgroundImage
        self.backgroundImageView.alpha = self.backgroundImageOpacity
        self.backgroundImageView.tintColor = UIColor.black
        self.messageLabel.text = self.message
        self.messageLabel.textColor = self.messageColor
        self.backgroundColor = UIColor.clear
        self.contentView.backgroundColor = self.faceColor
        self.setupHeights()
        
        // Round corners
        if self.cornerRadius != 0.0 {
            self.contentView.roundCorners(cornerRadius: self.cornerRadius)
        }
        
        // Add shadow
        if self.shadowSize != CGSize() {
            self.addShadow(shadowSize: self.shadowSize, shadowColor: self.shadowColor, shadowOpacity: self.shadowOpacity, shadowRadius: self.shadowRadius)
        }
    }
    
    public func setProportions(top: CGFloat = 0.1, image: CGFloat = 0.25, imageBottom: CGFloat = 0.05, title: CGFloat = 0.1, titleBottom: CGFloat = 0.1, message: CGFloat = 0.3, bottom: CGFloat = 0.1) {
        self.heightProportion = (top: top, image: image, imageBottom: imageBottom, title: title, titleBottom: titleBottom, message: message, bottom: bottom)
        self.setupHeights()
    }

    private func setupHeights() {
        let totalHeight: CGFloat = self.heightProportion.top + self.heightProportion.image + self.heightProportion.imageBottom + self.heightProportion.title + self.heightProportion.titleBottom + self.heightProportion.message + self.heightProportion.bottom
        let scale = self.frame.height / totalHeight
        
        self.topConstraint.constant = self.heightProportion.top * scale
        self.imageHeightConstraint.constant = self.heightProportion.image * scale
        self.imageBottomConstraint.constant = self.heightProportion.imageBottom * scale
        self.titleHeightConstraint.constant = self.heightProportion.title * scale
        self.titleBottomConstraint.constant = self.heightProportion.titleBottom * scale
        self.messageHeightConstraint.constant = self.heightProportion.message * scale
        self.bottomConstraint.constant = self.heightProportion.top * scale
        
    }
    
}
