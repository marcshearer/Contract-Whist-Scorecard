//
//  FocusView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class FocusView : UIView {
    
    private(set) var aroundFrame: CGRect!
    private var radius: CGFloat!
    private var fillColor: UIColor!
    private weak var parentViewController: ScorecardViewController!
    private weak var parentView: UIView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
    }
    
    convenience init(from parentViewController:ScorecardViewController, in parentView: UIView, around aroundFrame: CGRect? = nil) {
        self.init(frame: parentView.frame)
        self.accessibilityIdentifier = "focusView"
        self.parentViewController = parentViewController
        self.parentView = parentView
        parentView.addSubview(self)
        if let aroundFrame = aroundFrame {
            self.aroundFrame = aroundFrame
            self.createShapeLayers()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    public func set(around aroundFrame: CGRect, radius: CGFloat = 8, fillColor: UIColor? = nil) {
        self.aroundFrame = aroundFrame
        self.radius = radius
        self.fillColor = fillColor
        self.removeShapeLayers()
        self.createShapeLayers()
    }
    
    private func removeShapeLayers() {
        if let sublayers = self.layer.sublayers {
            for layer in sublayers {
                if layer is CAShapeLayer || layer is CAShapeLayer {
                    layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    private func createShapeLayers() {
        let path = UIBezierPath()
        self.draw(frame: parentViewController.screenBounds, in: path, radius: 0)
        self.draw(frame: self.aroundFrame, in: path, radius: self.radius)
        let layer = CAShapeLayer()
        layer.fillRule = .evenOdd
        layer.fillColor = (self.fillColor ?? UIColor.black.withAlphaComponent(0.6)).cgColor
        layer.lineWidth = 0
        layer.path = path.cgPath
        self.layer.insertSublayer(layer, at: 0)
    }
    
    private func draw(frame: CGRect, in path: UIBezierPath, radius: CGFloat) {
        path.move(to: CGPoint(x: frame.minX + radius, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX - radius, y: frame.minY))
        if radius > 0 {
            path.addArc(withCenter: CGPoint(x: frame.maxX - radius, y: frame.minY + radius), radius: radius, startAngle: 1.5 * .pi, endAngle: 2.0 * .pi, clockwise: true)
        }
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - radius))
        if radius > 0 {
            path.addArc(withCenter: CGPoint(x: frame.maxX - radius, y: frame.maxY - radius), radius: radius, startAngle: 0 * .pi, endAngle: 0.5 * .pi, clockwise: true)
        }
        path.addLine(to: CGPoint(x: frame.minX + radius, y: frame.maxY))
        if radius > 0 {
            path.addArc(withCenter: CGPoint(x: frame.minX + radius, y: frame.maxY - radius), radius: radius, startAngle: 0.5 * .pi, endAngle: 1.0 * .pi, clockwise: true)
        }
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY + radius))
        if radius > 0 {
            path.addArc(withCenter: CGPoint(x: frame.minX + radius, y: frame.minY + radius), radius: radius, startAngle: 1.0 * .pi, endAngle: 1.5 * .pi, clockwise: true)
        }
    }
    
    private func surrounding(points: [CGPoint]) -> CGRect {
        let minX = points.reduce(CGFloat.greatestFiniteMagnitude, { min($0, $1.x) })
        let maxX = points.reduce(-CGFloat.greatestFiniteMagnitude, { max($0, $1.x) })
        let minY = points.reduce(CGFloat.greatestFiniteMagnitude, { min($0, $1.y) })
        let maxY = points.reduce(-CGFloat.greatestFiniteMagnitude, { max($0, $1.y) })
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func midPoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
        return CGPoint(x: (point1.x + point2.x) / 2,
                       y: (point1.y + point2.y) / 2)
    }
}
