//
//  Shadow View.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class ShadowView : UIView {
    // Just used to identify specific subview
}

extension UIView {
        
    public func addShadow(shadowSize: CGSize, shadowColor: UIColor? = nil, shadowOpacity: CGFloat = 0.2, shadowRadius: CGFloat? = nil) {
        
        let shadowColor = shadowColor ?? UIColor.black
        let shadowRadius = shadowRadius ?? min(shadowSize.width, shadowSize.height)
        self.layer.shadowOpacity = Float(shadowOpacity)
        self.layer.shadowOffset = shadowSize
        self.layer.shadowColor = shadowColor.cgColor
        self.layer.shadowRadius = shadowRadius
    }
        /* TODO  My version
              var shadowView: ShadowView!
        
        // Find/create subviews
        for view in self.subviews {
            if view is ShadowView {
                shadowView = view as? ShadowView
            }
        }
        if shadowView == nil {
            shadowView = ShadowView()
            self.addSubview(shadowView!)
            self.sendSubviewToBack(shadowView)
        }
        shadowView.frame = self.bounds.offsetBy(dx: shadowSize.width, dy: shadowSize.height)
        
        // Setup gradients
        let darkColor = shadowColor ?? UIColor.black.withAlphaComponent(0.05)

        if shadowGradient {
            
            var rounded = false
            if shadowSize.height > 0.0 {
                rounded = bottomRounded
            } else {
                rounded = topRounded
            }

            // Vertical gradient top or bottom
            var minX: CGFloat
            var minY: CGFloat
            var start: CGFloat
           
            let verticalGradient = CAGradientLayer()
            if shadowSize.height > 0.0 {
                minX = 0.0
                minY = shadowView!.frame.height - shadowSize.height - cornerRadius
                start = 0.0
            } else {
                minX = abs(shadowSize.width) + cornerRadius
                minY = 0.0
                start = 1.0
            }
            verticalGradient.frame = CGRect(x: minX,
                                            y: minY,
                                            width: shadowView.frame.width - (rounded ? abs(shadowSize.width) + cornerRadius : 0.0),
                                            height: abs(shadowSize.height) + cornerRadius)
            verticalGradient.colors = [darkColor.cgColor, UIColor.clear.cgColor]
            verticalGradient.startPoint = CGPoint(x: 0.0, y: start)
            verticalGradient.endPoint = CGPoint(x: 0.0, y: 1.0 - start)
            if !rounded {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: 0))
                path.move(to: CGPoint(x: 0, y: self.frame.width))
                path.move(to: CGPoint(x: self.frame.width + shadowSize.width, y: shadowSize.height))
                path.move(to: CGPoint(x: 0, y: shadowSize.height))
                path.closeSubpath()
                verticalGradient.shadowPath = path
            }
            shadowView.layer.insertSublayer(verticalGradient, at: 0)
            
            // Horizontal gradient to the sidelet horizontalGradient = CAGradientLayer()
            let horizontalGradient = CAGradientLayer()
            if shadowSize.width > 0.0 {
                minX = shadowView.frame.width - shadowSize.width - cornerRadius
                minY = 0.0
                start = 0.0
            } else {
                minX = 0.0
                minY = abs(shadowSize.width) + cornerRadius
                start = 1.0
            }
            horizontalGradient.frame = CGRect(x: minX,
                                              y: minY,
                                              width: abs(shadowSize.width) + cornerRadius,
                                              height: shadowView.frame.height - (true ? abs(shadowSize.height) + cornerRadius : 0.0))
            horizontalGradient.colors = [darkColor.cgColor, UIColor.clear.cgColor]
            horizontalGradient.startPoint = CGPoint(x: start, y: 0.0)
            horizontalGradient.endPoint = CGPoint(x: 1.0 - start, y: 0.0)
            shadowView.layer.insertSublayer(horizontalGradient, at: 0)
            
            if rounded {
                // Outside corner gradient
                let cornerGradient = CAGradientLayer()
                var origin = CGPoint()
                var startX = 1.0
                var startY = 1.0
                if shadowSize.width > 0.0 {
                    origin.x = shadowView.frame.width - shadowSize.width - cornerRadius
                    startX = 0.0
                }
                if shadowSize.height > 0.0 {
                    origin.y = shadowView.frame.height - shadowSize.height - cornerRadius
                    startY = 0.0
                }
                
                cornerGradient.frame = CGRect(origin: origin,
                                              size: CGSize(width: abs(shadowSize.width) + cornerRadius,
                                                           height: abs(shadowSize.height) + cornerRadius))
                cornerGradient.colors = [darkColor.cgColor, UIColor.clear.cgColor]
                cornerGradient.startPoint = CGPoint(x: startX, y: startY)
                cornerGradient.endPoint = CGPoint(x: 1.0 - startX, y: 1.0 - startY)
                cornerGradient.type = .radial
                shadowView.layer.insertSublayer(cornerGradient, at: 0)
            }
        } else {
            shadowView.backgroundColor = darkColor
        }
        shadowView.roundCorners(cornerRadius: cornerRadius, topRounded: topRounded, bottomRounded: bottomRounded)
    }
      
    */
 
    public func roundCorners(cornerRadius: CGFloat, topRounded:Bool = true, bottomRounded: Bool = true) {
        if topRounded || bottomRounded {
            var roundedCorners: UIRectCorner = []
            if topRounded && bottomRounded {
                roundedCorners = .allCorners
            } else if topRounded {
                roundedCorners = [.topLeft, .topRight]
            } else {
                roundedCorners = [.bottomLeft, .bottomRight]
            }
            let layerMask = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: [roundedCorners], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            let layer = CAShapeLayer()
            layer.frame = self.bounds
            layer.path = layerMask.cgPath
            self.layer.mask = layer
        }
    }
}

