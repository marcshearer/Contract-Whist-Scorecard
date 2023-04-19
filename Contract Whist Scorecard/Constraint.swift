//
//  Constraint.swift
//  Time Clocking
//
//  Created by Marc Shearer on 31/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//


import UIKit

enum ConstraintAnchor: CustomStringConvertible {
    case leading
    case trailing
    case top
    case bottom
    case all
    case horizontal
    case vertical
    case centerX
    case centerY
    case safeLeading
    case safeTrailing
    case safeTop
    case safeBottom
    case safeAll
    case safeHorizontal
    case safeVertical
    
    var safe: Bool {
        return self == .safeLeading || self == .safeTrailing || self == .safeTop || self == .safeBottom || self == .safeAll || self == .safeHorizontal || self == .safeVertical
    }
    
    var description: String {
        switch self {
        case .leading, .safeLeading:
            return ".leading"
        case .trailing, .safeTrailing:
            return ".trailing"
        case .top, .safeTop:
            return ".top"
        case .bottom, .safeBottom:
            return ".bottom"
        case .all, .safeAll:
            return ".all"
        case .horizontal, .safeHorizontal:
            return ".horizontal"
        case .vertical, .safeVertical:
            return ".vertical"
        case .centerX:
            return ".centerX"
        case .centerY:
            return ".centerY"
        }
    }

    var constraint: NSLayoutConstraint.Attribute {
        switch self {
        case .leading, .safeLeading:
            return .leading
        case .trailing, .safeTrailing:
            return .trailing
        case .top, .safeTop:
            return .top
        case .bottom, .safeBottom:
            return .bottom
        case .all, .safeAll, .horizontal, .safeHorizontal, .vertical, .safeVertical:
            fatalError("Not supported")
        case .centerX:
            return .centerX
        case .centerY:
            return .centerY
        }
    }
    
    var expanded: [ConstraintAnchor] {
        switch self {
        case .horizontal:
            return [.leading, .trailing]
        case .vertical:
            return [.top, .bottom]
        case .all:
            return [.leading, .trailing, .top, .bottom]
        case .safeAll:
            return [.safeLeading, .safeTrailing, .safeTop, .safeBottom]
        case .safeHorizontal:
            return [.safeLeading, .safeTrailing]
        case .safeVertical:
            return [.safeTop, .safeBottom]
        default:
            return [self]
        }
    }
    
    var opposite: ConstraintAnchor? {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        case .top:
            return .bottom
        case .bottom:
            return .top
        case .safeLeading:
            return .safeTrailing
        case .safeTrailing:
            return .safeLeading
        case .safeTop:
            return .safeBottom
        case .safeBottom:
            return .safeTop
        case .all, .safeAll, .horizontal, .safeHorizontal, .vertical, .safeVertical:
            return nil
        case .centerX:
            return .centerX
        case .centerY:
            return .centerY
        }
    }
}

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
    @discardableResult public static func anchor(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0, toAttribute: ConstraintAnchor? = nil, priority: UILayoutPriority = .required, attributes: ConstraintAnchor...) -> [NSLayoutConstraint] {
        
        Constraint.anchor(view: view, control: control, to: to, multiplier: multiplier, constant: constant, toAttribute: toAttribute, priority: priority, attributes: attributes)
    }
    
    @discardableResult public static func anchor(view: UIView, control: UIView, to: UIView? = nil, multiplier: CGFloat = 1.0, constant: CGFloat = 0.0, toAttribute: ConstraintAnchor? = nil, priority: UILayoutPriority = .required, attributes anchorAttributes: [ConstraintAnchor]) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let anchorAttributes = (anchorAttributes.count == 0 ? [.all] : anchorAttributes)
        var attributes: [ConstraintAnchor] = []
        for attribute in anchorAttributes {
            attributes.append(contentsOf: attribute.expanded)
        }
        let to = to ?? view
        control.translatesAutoresizingMaskIntoConstraints = false
        control.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        for attribute in attributes {
            let toAttribute = toAttribute ?? attribute
            let control = attribute.safe ? control.safeAreaLayoutGuide : control
            let to = toAttribute.safe ? to.safeAreaLayoutGuide : to
            let sign: CGFloat = (attribute == .trailing || attribute == .bottom ? -1.0 : 1.0)
            let constraint = NSLayoutConstraint(item: control, attribute: attribute.constraint, relatedBy: .equal, toItem: to, attribute: toAttribute.constraint, multiplier: multiplier, constant: constant * sign)
            constraint.priority = priority
            view.addConstraint(constraint)
            constraints.append(constraint)
        }
        return constraints
    }
    
    func layoutGuide(_ view: UIView?, anchor: ConstraintAnchor) -> Any? {
        if anchor.safe {
            return view?.safeAreaInsets
        } else {
            return view
        }
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
