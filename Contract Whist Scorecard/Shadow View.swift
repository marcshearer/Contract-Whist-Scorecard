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
        
    public func addShadow(shadowSize: CGSize = CGSize(width: 4.0, height: 4.0), shadowColor: UIColor? = nil, shadowOpacity: CGFloat = 0.2, shadowRadius: CGFloat? = nil) {
        
        let shadowColor = shadowColor ?? UIColor.black
        let shadowRadius = shadowRadius ?? min(shadowSize.width, shadowSize.height) / 2.0
        self.layer.shadowOpacity = Float(shadowOpacity)
        self.layer.shadowOffset = shadowSize
        self.layer.shadowColor = shadowColor.cgColor
        self.layer.shadowRadius = shadowRadius
    }
    
    public func removeShadow() {
        self.layer.shadowOffset = CGSize()
        self.clipsToBounds = false
    }
       
    public func roundCorners(cornerRadius: CGFloat, topRounded:Bool = true, bottomRounded: Bool = true) {
        if topRounded || bottomRounded {
            var corners: UIRectCorner = []
            if topRounded && bottomRounded {
                corners = .allCorners
            } else if topRounded {
                corners = [.topLeft, .topRight]
            } else {
                corners = [.bottomLeft, .bottomRight]
            }
            self.roundCorners(cornerRadius: cornerRadius, corners: corners)
        } else {
            self.layer.mask = nil
        }
    }
    
    public func roundCorners(cornerRadius: CGFloat, corners: UIRectCorner) {
        if !corners.isEmpty {
            let layerMask = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            let layer = CAShapeLayer()
            layer.frame = self.bounds
            layer.path = layerMask.cgPath
            self.layer.mask = layer
        } else {
            self.layer.mask = nil
        }
    }
    
    public func removeRoundCorners() {
        self.layer.mask = nil
    }
}

