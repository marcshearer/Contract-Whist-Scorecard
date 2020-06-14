//
//  Buttons.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class RoundedButton: UIButton {
    
    var normalTextColor = Palette.darkHighlightText
    var normalBackgroundColor = Palette.darkHighlight
    var normalTextAlpha: CGFloat = 1.0
    var normalBackgroundAlpha: CGFloat = 1.0
    var disabledTextColor = Palette.highlightText
    var disabledBackgroundColor = Palette.highlight
    var disabledBackgroundAlpha: CGFloat = 0.3
    var disabledTextAlpha: CGFloat = 1.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.toRounded()
        self.titleLabel?.adjustsFontSizeToFitWidth = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
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
    
    func toCircle() {
        self.layer.cornerRadius = self.layer.bounds.height / 2
        self.layer.masksToBounds = true
    }
    
    func toRounded(cornerRadius: CGFloat = 5.0) {
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
    }
    
    func toUnrounded() {
        self.layer.cornerRadius = 0
        self.layer.masksToBounds = true
    }
    
    func setTitle(_ title: String) {
        // Set title
        super.setTitle(title, for: .normal)
    }
}

class LightRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.black
        self.normalBackgroundColor = Palette.highlight
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
        self.normalTextColor = Palette.darkHighlightText
        self.normalBackgroundColor = Palette.darkHighlight
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.darkHighlight
        self.disabledBackgroundColor = Palette.darkHighlight
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class BidButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.bidButtonText
        self.normalBackgroundColor = Palette.bidButton
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.bidButtonText
        self.disabledBackgroundColor = Palette.bidButton
        self.disabledTextAlpha = 0.9
        self.disabledBackgroundAlpha = 0.5
        super.isEnabled(true)
    }
}

class EmphasisRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.emphasisText
        self.normalBackgroundColor = Palette.emphasis
        self.normalTextAlpha = 1.0
        self.normalBackgroundAlpha = 1.0
        self.disabledTextColor = Palette.emphasisText
        self.disabledBackgroundColor = Palette.emphasis
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
        self.normalBackgroundColor = Palette.total
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
        self.normalBackgroundColor = Palette.error
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


