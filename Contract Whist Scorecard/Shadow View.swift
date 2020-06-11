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
    
    public func removeShadow() {
        self.layer.shadowOffset = CGSize()
    }
       
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

