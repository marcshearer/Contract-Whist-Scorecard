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
        constraint.priority = UILayoutPriority.required
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func setHeight(control: UIView, height: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height)
        constraint.priority = UILayoutPriority.required
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func anchor(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0, toAttribute: NSLayoutConstraint.Attribute? = nil, attributes: NSLayoutConstraint.Attribute...) {
        let to = to ?? view
        control.translatesAutoresizingMaskIntoConstraints = false
        control.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        for attribute in attributes {
            let toAttribute = toAttribute ?? attribute
            let sign: CGFloat = (attribute == .trailing || attribute == .bottom ? -1.0 : 1.0)
            let constraint = NSLayoutConstraint(item: control, attribute: attribute, relatedBy: .equal, toItem: to, attribute: toAttribute, multiplier: multiplier, constant: constant * sign)
            constraint.priority = UILayoutPriority.required
            view.addConstraint(constraint)
        }
    }

    public static func proportionalWidth(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0) {
        let to = to ?? view
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: to, attribute: .width, multiplier: multiplier, constant: 0.0)
        constraint.priority = UILayoutPriority.required
        view.addConstraint(constraint)
    }

    
    public static func proportionalHeight(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0) {
        let to = to ?? view
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: to, attribute: .height, multiplier: multiplier, constant: 0.0)
        constraint.priority = UILayoutPriority.required
        view.addConstraint(constraint)
    }
}
