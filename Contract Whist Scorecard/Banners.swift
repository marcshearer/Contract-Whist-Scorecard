//
//  Banners.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/03/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

// Used as a padding view for devices such as iPhone X where there is some space around the safe area

import UIKit

class InsetPaddingViewNoColor: UIView {

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
}

class InsetPaddingView: InsetPaddingViewNoColor {
    
    @IBInspectable var bannerColor: UIColor {
        didSet {
            self.backgroundColor = bannerColor
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        self.bannerColor = Palette.banner.background
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        self.backgroundColor = self.bannerColor
        super.layoutSubviews()
    }
    
}

@objc enum ContinuationShapeType: Int {
    case rectangle = 0
    case upArrow = 1
    case downArrow = 2
    case leftStep = 3
}

class BannerContinuation: UIView {
    
    private var shapeLayer: [CAShapeLayer] = []
    
    @IBInspectable var bannerColor: UIColor
    @IBInspectable var borderColor: UIColor
    @IBInspectable var shape: ContinuationShapeType
    
    @IBInspectable var shapeType:Int {
        get {
            return self.shape.rawValue
        }
        set(shapeType) {
            self.shape = ContinuationShapeType(rawValue: shapeType) ?? .upArrow
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.bannerColor = Palette.banner.background
        self.borderColor = Palette.banner.background
        self.shape = .upArrow
        super.init(coder: aDecoder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove previous layers
        self.shapeLayer.forEach { $0.removeFromSuperlayer() }
        
        for pass in 0...(self.bannerColor == self.borderColor ? 0 : 1) {
            
            var color: UIColor
            var points: [PolygonPoint] = []
            var rect: CGRect
            
            if pass == 1 {
                rect = CGRect(x: 0.0, y: 0.0, width: self.frame.width, height: self.frame.height)
                color = self.borderColor
            } else {
                rect = CGRect(x: 0.0, y: 0.0, width: self.frame.width, height: self.frame.height - 5.0)
                color = self.bannerColor
            }
            
            switch self.shape {
            case .rectangle:
                points.append(PolygonPoint(x: rect.minX, y: rect.minY, pointType: .point))
                points.append(PolygonPoint(x: rect.minX, y: rect.maxY, pointType: .point))
                points.append(PolygonPoint(x: rect.maxX, y: rect.maxY, pointType: .point))
                points.append(PolygonPoint(x: rect.maxX, y: rect.minY, pointType: .point))
                
            case .upArrow:
                points.append(PolygonPoint(x: rect.minX, y: rect.minY, pointType: .point))
                points.append(PolygonPoint(x: rect.minX, y: rect.maxY, pointType: .point))
                points.append(PolygonPoint(x: rect.midX, y: rect.minY + (pass == 1 ? 5.0 : 0.0), pointType: .quadRounded, radius: 20.0))
                points.append(PolygonPoint(x: rect.maxX, y: rect.maxY, pointType: .point))
                points.append(PolygonPoint(x: rect.maxX, y: rect.minY, pointType: .point))
                
            case .leftStep:
                let arrowWidth: CGFloat = (rect.height / 1.5)
                points.append(PolygonPoint(x: rect.minX, y: rect.minY, pointType: .point))
                points.append(PolygonPoint(x: rect.minX, y: rect.maxY, pointType: .point))
                points.append(PolygonPoint(x: rect.midX - (arrowWidth / 2.0), y: rect.maxY, radius: 10.0))
                points.append(PolygonPoint(x: rect.midX + (arrowWidth / 2.0), y: rect.minY, pointType: .smoothQuadRounded, radius: 5.0))
                
            case .downArrow:
                points.append(PolygonPoint(x: rect.minX, y: rect.minY, pointType: .point))
                if pass == 1 {
                    points.append(PolygonPoint(x: rect.minX, y: rect.minY + 5.0, pointType: .point))
                }
                points.append(PolygonPoint(x: rect.midX, y: rect.maxY, pointType: .quadRounded, radius: 20.0))
                if pass == 1 {
                    points.append(PolygonPoint(x: rect.maxX, y: rect.minY + 5.0, pointType: .point))
                }
                points.append(PolygonPoint(x: rect.maxX, y: rect.minY, pointType: .point))
                
            default:
                break
            }
            self.shapeLayer.append(Polygon.roundedShapeLayer(in: self, definedBy: points, strokeColor: color, fillColor: color, lineWidth: 0.0))
        }
    }
    
}

class Footer: UIView {
    
    private var shapeLayer: [CAShapeLayer] = []
    
    @IBInspectable var footerColor: UIColor
    @IBInspectable var borderColor: UIColor
    @IBInspectable var shape: ContinuationShapeType
    
    @IBInspectable var shapeType:Int {
        get {
            return self.shape.rawValue
        }
        set(shapeType) {
            self.shape = ContinuationShapeType(rawValue: shapeType) ?? .upArrow
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.footerColor = Palette.banner.background
        self.borderColor = Palette.banner.text
        self.shape = .upArrow
        super.init(coder: aDecoder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove previous layer
        self.shapeLayer.forEach { $0.removeFromSuperlayer() }
        
        for pass in 0...(self.footerColor == self.borderColor ? 0 : 1) {
            
            var color: UIColor
            var points: [PolygonPoint] = []
            var rect: CGRect
            
            if pass == 1 {
                rect = CGRect(x: 0.0, y: 0.0, width: self.frame.width, height: self.frame.height)
                color = self.borderColor
            } else {
                rect = CGRect(x: 0.0, y: 5.0, width: self.frame.width, height: self.frame.height - 5.0)
                color = self.footerColor
            }
            
            // Add new layer
            switch self.shape {
            case .upArrow:
                points.append(PolygonPoint(x: rect.minX, y: rect.maxY, pointType: .point))
                if pass == 1 {
                    points.append(PolygonPoint(x: rect.minX, y: rect.maxY - 5.0, pointType: .point))
                }
                points.append(PolygonPoint(x: rect.midX, y: rect.minY, pointType: .quadRounded, radius: 20.0))
                if pass == 1 {
                    points.append(PolygonPoint(x: rect.maxX, y: rect.maxY - 5.0, pointType: .point))
                }
                points.append(PolygonPoint(x: rect.maxX, y: rect.maxY, pointType: .point))
                
            default:
                break
            }
            self.shapeLayer.append(Polygon.roundedShapeLayer(in: self, definedBy: points, strokeColor: color, fillColor: color, lineWidth: 0.0))
        }
    }
    
}


class NavigationBar: UINavigationBar {
    
    @IBInspectable var bannerColor: UIColor
    @IBInspectable var textColor: UIColor
    
    required init?(coder: NSCoder) {
        self.bannerColor = Palette.banner.background
        self.textColor = Palette.banner.text
        super.init(coder: coder)
        self.setBackgroundImage(UIImage(), for: .default)
        self.shadowImage = UIImage()
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: self.frame.height))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textAlignment = .center
        self.topItem?.titleView = titleLabel
    }
    
    override func draw(_ rect: CGRect) {
        if let titleText = self.topItem?.title, let titleLabel = self.topItem?.titleView as! UILabel? {
            titleLabel.text = titleText
        }
        super.draw(rect)
    }
    
    func setTitle(_ title: String) {
        if let topItem = self.topItem {
            topItem.title = title
            if let titleLabel = topItem.titleView as? UILabel {
                titleLabel.text = title
            }
        }
    }
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        self.isTranslucent = false
        self.barTintColor = self.bannerColor
        self.backgroundColor = self.bannerColor
        
        var fontSize: CGFloat
        if ScorecardUI.landscapePhone() {
            fontSize = min(28.0, CGFloat(Int(UIScreen.main.bounds.width / 14)))
        } else {
            fontSize = min(28.0, CGFloat(Int(UIScreen.main.bounds.width / 12)))
        }
        if let titleText = self.topItem?.title, let titleLabel = self.topItem?.titleView as! UILabel? {
            titleLabel.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let titleSize = titleText.size(withAttributes: [NSAttributedString.Key.font: titleLabel.font!])
            titleLabel.frame = CGRect(x: 0.0, y: 0.0, width: titleSize.width, height: self.frame.height)
            titleLabel.textAlignment = .center
            titleLabel.text = titleText
            titleLabel.textColor = self.textColor
        }
    }
}
