//
//  ButtonGroupView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

/// Resizing container a bit like a stack view which you can drop other views into

import UIKit

class ViewGroup: UIView {
    
    @IBInspectable private var spacing: CGFloat = 4.0
    
    private var viewList: [UIView] = []
    private var constraintList: [NSLayoutConstraint] = []
    
    @IBOutlet private weak var contentView: UIView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadButtonGroupView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadButtonGroupView()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Find views in group and move to content view
        for view in self.subviews {
            if view !== self.contentView {
                view.removeFromSuperview()
                self.addView(view)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.arrange()
    }
    
    public func add(view: UIView) {
        self.addView(view)
        self.arrange()
    }
    
    public func isHidden(view: UIView, _ hidden: Bool) {
        if view.isHidden != hidden {
            view.isHidden = hidden
            self.arrange()
        }
    }
    
    private func addView(_ view: UIView) {
        self.contentView.addSubview(view)
        self.viewList.append(view)
        // Remove any existing constraints on subviews
        for constraint in view.constraints {
            view.removeConstraint(constraint)
        }
        // Add height, width and vertical center constraints
        Constraint.setWidth(control: view, width: view.frame.width)
        Constraint.setHeight(control: view, height: view.frame.height)
        Constraint.anchor(view: self.contentView, control: view, attributes: .centerY)
    }
    
    private func loadButtonGroupView() {
        Bundle.main.loadNibNamed("ViewGroup", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func arrange() {
        var width: CGFloat = 0
        var lastView: UIView?
        
        // Remove previously created constraints
        for constraint in self.constraintList {
            self.contentView.removeConstraint(constraint)
        }
        self.constraintList = []
        
        // Bind each control to the one before it
        for view in self.viewList {

            if !view.isHidden {
                
                if lastView == nil {
                    // Bind first control to start of container
                    self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: view, attributes: .leading))
                }
                
                // Set constraints for view relative to previous views
                if lastView != nil {
                    self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: view, to: lastView, constant: self.spacing, toAttribute: .trailing, attributes: .leading))
                    width += spacing
                }
                width += view.frame.width
                lastView = view
            }
        }
        
        if let lastView = lastView {
            // Bind last control to end of container
            self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: lastView, attributes: .trailing))
        }
        
        // Set total width
        self.constraintList.append(Constraint.setWidth(control: self.contentView, width: width))
        
        self.contentView.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
