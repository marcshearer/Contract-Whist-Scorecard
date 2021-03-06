//
//  Buttons.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class RoundedButton: UIButton {
    
    private var cornerRadius: CGFloat = 5.0
    
    var normalTextColor = Palette.darkHighlight.text
    var normalBackgroundColor = Palette.darkHighlight.background
    var normalTextAlpha: CGFloat = 1.0
    var normalBackgroundAlpha: CGFloat = 1.0
    var disabledTextColor = Palette.highlight.text
    var disabledBackgroundColor = Palette.highlight.background
    var disabledBackgroundAlpha: CGFloat = 0.3
    var disabledTextAlpha: CGFloat = 1.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.titleLabel?.adjustsFontSizeToFitWidth = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.toRounded()
    }
    
    func isEnabled(_ enabled: Bool) {
        if enabled {
            self.setTitleColor(self.normalTextColor.withAlphaComponent(self.normalTextAlpha), for: .normal)
            self.backgroundColor = self.normalBackgroundColor.withAlphaComponent(self.normalBackgroundAlpha)
            self.isEnabled = true
        } else {
            self.setTitleColor(self.disabledTextColor.withAlphaComponent(self.disabledTextAlpha), for: .disabled)
            self.backgroundColor = self.disabledBackgroundColor.withAlphaComponent(self.disabledBackgroundAlpha)
            self.isEnabled = false
        }
    }
    
    public func setTitleFont(_ font: UIFont) {
        self.titleLabel?.font = font
    }
    
    func toCircle() {
        self.cornerRadius = self.layer.bounds.height / 2
        self.layer.cornerRadius = self.cornerRadius
        self.layer.masksToBounds = true
    }
    
    func toRounded(cornerRadius: CGFloat? = nil) {
        self.cornerRadius = cornerRadius ?? self.cornerRadius
        self.layer.cornerRadius = self.cornerRadius
        self.layer.masksToBounds = true
    }
    
    func toUnrounded() {
        self.cornerRadius = 0.0
        self.layer.cornerRadius = 0.0
        self.layer.masksToBounds = false
    }
    
    func setTitle(_ title: String) {
        // Set title
        super.setTitle(title, for: .normal)
    }
}

class ShadowButton: UIButton {
    
    @IBInspectable var shadowSize = CGSize(width: 4.0, height: 4.0)
    @IBInspectable var shadowOpacity: CGFloat = 0.2
    @IBInspectable var cornerRadius: CGFloat = 5.0
    
    private var internalUpdate = false
    private var customBackgroundColor: UIColor?
    private var titleInnerLabel: UILabel?
    private var titleOuterLabel: UILabel?
    private var hasInherited = false
    
    override var backgroundColor: UIColor? {
        didSet {
            if !internalUpdate {
                fatalError("Don't set the background color directly. Use the helper routine")
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            if self.isEnabled {
                self.titleOuterLabel?.backgroundColor = customBackgroundColor ?? self.backgroundColor
            } else {
                self.titleOuterLabel?.backgroundColor = (customBackgroundColor ?? self.backgroundColor)?.withAlphaComponent(0.5)
            }
        }
    }
       
    required init(coder aDecoder: NSCoder) {
        self.internalUpdate = true
        super.init(coder: aDecoder)!
        self.internalUpdate = false
    }
    
    override init(frame: CGRect) {
        self.internalUpdate = true
        super.init(frame: frame)
        self.internalUpdate = false
        self.awakeFromNib()
    }
    
    init(frame: CGRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        self.internalUpdate = true
        super.init(frame: frame)
        self.internalUpdate = false
        self.awakeFromNib()
}
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.internalUpdate = true
        self.inheritProperties()
        self.internalUpdate = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.titleOuterLabel?.layoutIfNeeded()
        self.titleInnerLabel?.setNeedsLayout()
        if self.titleOuterLabel != nil {
            self.addShadow()
        }
    }
    
    private func inheritProperties() {
        // Replace existing title label (which hugs text) with a full size label for the background
        // and an inset label to contain the text
        
        let title = self.currentTitle
        self.titleOuterLabel = UILabel(frame: self.frame)
        self.titleOuterLabel?.backgroundColor = self.backgroundColor
        self.titleOuterLabel?.accessibilityIdentifier = "outerLabel"
        self.addSubview(self.titleOuterLabel!)
        Constraint.anchor(view: self, control: self.titleOuterLabel!)
        self.bringSubviewToFront(self.imageView!)
        
        self.titleInnerLabel = UILabel(frame: CGRect(x: 5, y: 1,
                    width: self.frame.width - 10, height: self.frame.height - 2))
        self.titleInnerLabel?.backgroundColor = UIColor.clear
        self.titleInnerLabel?.textColor = self.titleOuterLabel?.textColor
        self.titleInnerLabel?.text = title
        self.titleInnerLabel?.textAlignment = .center
        self.titleInnerLabel?.font = self.titleLabel!.font
        self.titleInnerLabel?.adjustsFontSizeToFitWidth = true
        self.titleInnerLabel?.accessibilityIdentifier = "innerLabel"
        self.titleOuterLabel?.addSubview(self.titleInnerLabel!)
        Constraint.anchor(view: self.titleOuterLabel!, control: self.titleInnerLabel!, attributes: .centerX, .centerY)
        Constraint.setWidth(control: self.titleInnerLabel!, width: self.frame.width - 10)
        Constraint.setHeight(control: self.titleInnerLabel!, height: self.frame.height - 2)

        if self.image(for: .normal) != nil {
            self.bringSubviewToFront(self.imageView!)
        }

        self.backgroundColor = UIColor.clear
        self.titleLabel?.removeFromSuperview()
        self.hasInherited = true
    }
            
    public func setBackgroundColor(_ backgroundColor: UIColor) {
        if !self.hasInherited {
            self.internalUpdate = true
            self.backgroundColor = backgroundColor
            self.internalUpdate = false
        } else {
            self.customBackgroundColor = backgroundColor
            self.titleOuterLabel?.backgroundColor = backgroundColor
        }
    }
    
    public override func setTitleColor(_ titleColor: UIColor?, for: UIControl.State) {
        if !self.hasInherited {
            super.setTitleColor(titleColor, for: state)
        } else {
            self.titleInnerLabel?.textColor = titleColor
        }
    }
    
    public override func setTitle(_ title: String?, for state: UIControl.State) {
        if !self.hasInherited {
            // Haven't taken control yet
            super.setTitle(title, for: state)
        } else {
            UIView.performWithoutAnimation {
                self.titleInnerLabel?.text = title
                self.titleOuterLabel?.alpha = 1
            }
        }
    }
    
    public func setTitleFont(_ font: UIFont) {
        if !self.hasInherited {
            // Haven't taken control yet
        } else {
            self.titleInnerLabel?.font = font
        }
    }
    
    public func setTitle(_ title: NSAttributedString) {
        self.titleInnerLabel?.attributedText = title
    }
    
    public func toCircle() {
        if let layer = self.titleOuterLabel?.layer {
            self.cornerRadius = layer.bounds.height / 2
            layer.cornerRadius = self.cornerRadius
            layer.masksToBounds = true
            self.addShadow()
        }
    }
    
    public func toRounded(cornerRadius: CGFloat? = nil) {
        if let layer = self.titleOuterLabel?.layer {
            self.cornerRadius = cornerRadius ?? self.cornerRadius
            layer.cornerRadius = self.cornerRadius
            self.layer.masksToBounds = true
            self.addShadow()
        }
    }
    
    func toUnrounded() {
        if let layer = self.titleOuterLabel?.layer {
            self.cornerRadius = 0.0
            layer.cornerRadius = 0.0
            layer.masksToBounds = false
            self.addShadow()
        }
    }
    
    private func addShadow() {
        self.titleOuterLabel?.textAlignment = .center
        self.titleOuterLabel?.adjustsFontSizeToFitWidth = true
        self.titleOuterLabel?.frame = CGRect(origin: CGPoint(), size: self.frame.size)
        Constraint.anchor(view: self, control: titleOuterLabel!)
        self.titleOuterLabel?.roundCorners(cornerRadius: self.cornerRadius)
        self.addShadow(shadowSize: self.shadowSize, shadowOpacity: self.shadowOpacity)
    }
    
}

class HelpButton: ShadowButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupHelpButton()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupHelpButton()
    }
    
    private func setupHelpButton() {
        self.setImage(UIImage(systemName: "questionmark"), for: .normal)
        self.setTitle("", for: .normal)
        self.setBackgroundColor(Palette.bannerShadow.background)
        self.tintColor = Palette.bannerShadow.text
        self.imageView?.contentMode = .scaleAspectFit
        self.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.toCircle()
    }
}

class LightRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.black
        self.normalBackgroundColor = Palette.highlight.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.3
        super.isEnabled(true)
    }
}

class DarkRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.darkHighlight.text
        self.normalBackgroundColor = Palette.darkHighlight.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.darkHighlight.background
        self.disabledBackgroundColor = Palette.darkHighlight.background
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class BidButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.bidButton.text
        self.normalBackgroundColor = Palette.bidButton.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.bidButton.text
        self.disabledBackgroundColor = Palette.bidButton.background
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class EmphasisRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.emphasis.text
        self.normalBackgroundColor = Palette.emphasis.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.emphasis.text
        self.disabledBackgroundColor = Palette.emphasis.background
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class DarkUnroundedButton: DarkRoundedButton {
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.toUnrounded()
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextColor = UIColor.lightGray
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.8
    }
}

class TotalRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = Palette.total.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class ErrorRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = Palette.error.background
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.0
        self.disabledBackgroundAlpha = 0.0
        super.isEnabled(true)
    }
}

class ClearButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = self.titleColor(for: .normal)! // Leave as declared
        self.normalBackgroundColor = UIColor.clear
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 0.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.0
        super.isEnabled(true)
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.normalTextColor = self.titleColor(for: .normal)! // Leave as declared
        self.normalBackgroundColor = UIColor.clear
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.3
        super.isEnabled(true)
    }
}

class OutlineButton: RoundedButton {
    
    @IBInspectable public var outlineColor: UIColor?
        {
        set (color) {
            self.layer.borderColor = color?.cgColor
        }
        
        get {
            if let color = self.layer.borderColor
            {
                return UIColor(cgColor: color)
            } else {
                return nil
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.borderWidth = 1.0
    }
}

class AngledButton: ClearButton {
    
    @IBInspectable var fillColor: UIColor!
    @IBInspectable var strokeColor: UIColor!
    @IBInspectable var lineWidth: CGFloat = 1.0
    
    private var layers: [CAShapeLayer] = []
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.fillColor = self.fillColor ?? UIColor.clear
        self.strokeColor = self.strokeColor ?? self.titleColor(for: .normal)
        
        var points: [PolygonPoint] = []
        let frame = CGRect(x: self.lineWidth / 2.0, y: self.lineWidth / 2.0, width: self.frame.width - self.lineWidth, height: self.frame.height - self.lineWidth)
        let angleSize: CGFloat = self.frame.height / 3.0
        points.append(PolygonPoint(x: frame.minX , y: frame.midY))
        points.append(PolygonPoint(x: frame.minX + angleSize, y: frame.minY))
        points.append(PolygonPoint(x: frame.maxX - angleSize, y: frame.minY))
        points.append(PolygonPoint(x: frame.maxX, y: frame.midY))
        points.append(PolygonPoint(x: frame.maxX - angleSize, y: frame.maxY))
        points.append(PolygonPoint(x: frame.minX + angleSize, y: frame.maxY))
        
        // Remove previous layers
        for layer in self.layers {
            layer.removeFromSuperlayer()
        }
        
        // Add new shape
        let layer = Polygon.roundedShapeLayer(in: self, definedBy: points, strokeColor: self.strokeColor, fillColor: self.fillColor, lineWidth: self.lineWidth)
        layers.append(layer)
        
        // Set button properties
        self.normalTextColor = self.titleColor(for: .normal)! // Leave as declared
        self.normalBackgroundColor = UIColor.clear
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.3
        self.isEnabled(true)
        
        self.superview?.bringSubviewToFront(self)
        self.bringSubviewToFront(self.titleLabel!)
        
        let inset: CGFloat = angleSize + min(5.0, (frame.width - 50.0) / 10.0)
        self.titleEdgeInsets = UIEdgeInsets.init(top: 5.0, left: inset, bottom: 5.0, right: inset)
        self.backgroundColor = UIColor.clear
    }
}

class RightClearButton: ClearButton {
    // Moves the image to the right
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.reflect()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.reflect()
    }
    
    private func reflect() {
        self.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.imageView?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
    }
}

class OldImageButton: RoundedButton {
    
    let spacing: CGFloat = 6.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.resize()
    }
    
    override func setTitle(_ title: String) {
        // Set title
        super.setTitle(title)
        self.resize()
    }
    
    func setImage(_ imageName: String) {
        super.setImage(UIImage(named: imageName), for: .normal)
        self.resize()
    }
    
    func resize() {
        let imageSize: CGSize = self.imageView!.image!.size
        let titleSize = self.currentTitle!.size(withAttributes: [NSAttributedString.Key.font: self.titleLabel!.font!])
        let totalHeight = imageSize.height + titleSize.height + self.spacing
        
        self.titleEdgeInsets = UIEdgeInsets(top: 0.0,
                                            left: -imageSize.width,
                                            bottom: -(totalHeight - titleSize.height),
                                            right: 0.0)
        
        self.imageEdgeInsets = UIEdgeInsets(top: -(totalHeight - imageSize.height),
                                            left: 0.0,
                                            bottom: 0.0,
                                            right: -titleSize.width)
        
        self.contentEdgeInsets = UIEdgeInsets(top: 0.0,
                                              left: 0.0,
                                              bottom: titleSize.height,
                                              right: 0.0)
    }
}

class SideImageButton: RoundedButton {
    
    let spacing: CGFloat = 10.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        super.isEnabled(true)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if imageView != nil {
            imageEdgeInsets = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: bounds.width - bounds.height + spacing)
            titleEdgeInsets = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        }
    }
    
    func setImage(_ imageName: String) {
        super.setImage(UIImage(named: imageName), for: .normal)
    }
}


