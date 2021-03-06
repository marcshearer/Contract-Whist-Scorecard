//
//  View Group.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

/// Resizing container a bit like a stack view which you can drop other views into

import UIKit

class ViewGroup: UIView {
    
    @IBInspectable internal var spacing: CGFloat = 4.0
    
    struct Item {
        weak var view: UIView!
        let width: CGFloat
        weak var widthConstraint: NSLayoutConstraint?
        
        init(view: UIView, width: CGFloat, widthConstraint: NSLayoutConstraint?) {
            self.view = view
            self.width = width
            self.widthConstraint = widthConstraint
        }
    }
    
    private var itemList: [Item] = []
    private var constraintList = WeakArray<NSLayoutConstraint>()
    public var count: Int { self.itemList.count }
    public var visibleCount: Int {
        get {
            var count = 0
            for item in itemList {
                if !item.view.isHidden {
                    count += 1
                }
            }
            return count
        }
    }
    
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
    
    public func clear() {
        for item in itemList {
            item.view.removeFromSuperview()
        }
        self.itemList = []
    }
    
    public func add(views: [UIView]) {
        for view in views {
            self.addView(view)
        }
        self.arrange(layout: true)
    }
    
    public func isHidden(view: UIView, _ hidden: Bool) {
        if view.isHidden != hidden {
            view.isHidden = hidden
            self.arrange(layout: true)
        }
    }
    
    private func addView(_ view: UIView) {
        self.contentView.addSubview(view)
        // Remove any existing constraints on subviews
        for constraint in view.constraints {
            view.removeConstraint(constraint)
        }
        // Add height, width and vertical center constraints
        let widthConstraint = Constraint.setWidth(control: view, width: view.frame.width)
        Constraint.setHeight(control: view, height: view.frame.height)
        Constraint.anchor(view: self.contentView, control: view, attributes: .centerY)
        self.itemList.append(Item(view: view, width: view.frame.width, widthConstraint: widthConstraint))
    }
    
    private func loadButtonGroupView() {
        Bundle.main.loadNibNamed("ViewGroup", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func arrange(layout: Bool = false) {
        var width: CGFloat = 0
        var lastView: UIView?
        
        // Remove previously created constraints
        for constraint in self.constraintList {
            self.contentView.removeConstraint(constraint)
        }
        self.constraintList.clear()
        if false && layout { // Not sure we can do this
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
        }
        
        // Bind each control to the one before it
        for item in self.itemList {

            if item.view.isHidden {
                
                item.widthConstraint?.constant = 0
                
            } else {
                
                item.widthConstraint?.constant = item.width
                
                if lastView == nil {
                    // Bind first control to start of container
                    self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: item.view, attributes: .leading))
                }
                
                // Set constraints for view relative to previous views
                if lastView != nil {
                    self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: item.view, to: lastView, constant: self.spacing, toAttribute: .trailing, attributes: .leading))
                    width += spacing
                }
                width += item.width
                lastView = item.view
            }
        }
        
        if let lastView = lastView {
            // Bind last control to end of container
            self.constraintList.append(contentsOf: Constraint.anchor(view: self.contentView, control: lastView, attributes: .trailing))
        }
        
        // Set total width
        self.constraintList.append(Constraint.setWidth(control: self.contentView, width: width))
                
        if layout {
            self.contentView.setNeedsUpdateConstraints()
            self.contentView.updateConstraintsIfNeeded()
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
        }
    }
}
