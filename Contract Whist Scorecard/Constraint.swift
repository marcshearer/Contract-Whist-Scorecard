//
//  Constraint.swift
//  Time Clocking
//
//  Created by Marc Shearer on 31/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//


import UIKit

class Constraint {
    
    public static func setWidth(control: UIView, width: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: width)
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func setHeight(control: UIView, height: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height)
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func anchor(view: UIView, control: UIView, to: UIView? = nil, toAttribute: NSLayoutConstraint.Attribute? = nil, attributes: NSLayoutConstraint.Attribute...) {
        let to = to ?? view
        for attribute in attributes {
            let toAttribute = toAttribute ?? attribute
            let constraint = NSLayoutConstraint(item: control, attribute: attribute, relatedBy: .equal, toItem: to, attribute: toAttribute, multiplier: 1.0, constant: 0.0)
            view.addConstraint(constraint)
        }
    }
}