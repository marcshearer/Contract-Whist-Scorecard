//
//  Constraint.swift
//  Time Clocking
//
//  Created by Marc Shearer on 31/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//


import UIKit

class Constraint {
    
    @discardableResult public static func setWidth(control: UIView, width: CGFloat, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: width)
        constraint.priority = priority
        control.addConstraint(constraint)
        return constraint
    }
    
    @discardableResult public static func setHeight(control: UIView, height: CGFloat, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height)
        constraint.priority = priority
        control.addConstraint(constraint)
        return constraint
    }
    
    /// Creates NS Layout Constraints in an easier way
    /// - Parameters:
    ///   - view: Containing view
    ///   - control: First control (in view)
    ///   - to: Optional second control (in view)
    ///   - multiplier: Constraint multiplier value
    ///   - constant: Constraint constant value
    ///   - toAttribute: Attribute on 'to' control if different
    ///   - priority: Constraint priority
    ///   - attributes: list of attributes (.leading, .trailing etc)
    /// - Returns: Array of contraints created (discardable)
    @discardableResult public static func anchor(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0, toAttribute: NSLayoutConstraint.Attribute? = nil, priority: UILayoutPriority = .required, attributes: NSLayoutConstraint.Attribute...) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let attributes = (attributes.count == 0 ? [.leading, .trailing, .top, .bottom] : attributes)
        let to = to ?? view
        control.translatesAutoresizingMaskIntoConstraints = false
        control.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        for attribute in attributes {
            let toAttribute = toAttribute ?? attribute
            let sign: CGFloat = (attribute == .trailing || attribute == .bottom ? -1.0 : 1.0)
            let constraint = NSLayoutConstraint(item: control, attribute: attribute, relatedBy: .equal, toItem: to, attribute: toAttribute, multiplier: multiplier, constant: constant * sign)
            constraint.priority = priority
            view.addConstraint(constraint)
            constraints.append(constraint)
        }
        return constraints
    }

    @discardableResult public static func proportionalWidth(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let to = to ?? view
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: to, attribute: .width, multiplier: multiplier, constant: 0.0)
        constraint.priority = priority
        view.addConstraint(constraint)
        return constraint
    }

    @discardableResult public static func proportionalHeight(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, priority: UILayoutPriority = .required) -> NSLayoutConstraint{
        let to = to ?? view
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: to, attribute: .height, multiplier: multiplier, constant: 0.0)
        constraint.priority = priority
        view.addConstraint(constraint)
        return constraint
    }
    
    @discardableResult public static func aspectRatio(control: UIView, multiplier: CGFloat = 1.0, priority: UILayoutPriority = .required) -> NSLayoutConstraint{
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: control, attribute: .height, multiplier: multiplier, constant: 0.0)
        constraint.priority = priority
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func setActive(_ group: [NSLayoutConstraint]!, to value: Bool) {
        group.forEach { (constraint) in
            Constraint.setActive(constraint, to: value)
        }
    }
    
    public static func setActive(_ constraint: NSLayoutConstraint, to value: Bool) {
        constraint.isActive = value
        constraint.priority = (value ? .required : UILayoutPriority(1.0))
    }
    
}
