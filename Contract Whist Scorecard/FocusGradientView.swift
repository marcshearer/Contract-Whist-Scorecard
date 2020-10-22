//
//  FocusGradientView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class FocusGradientView : UIView {
    
    private var aroundFrame: CGRect!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
    }
    
    convenience init(in view: UIView, around aroundFrame: CGRect? = nil) {
        self.init(frame: view.frame)
        view.addSubview(self)
        if let aroundFrame = aroundFrame {
            self.aroundFrame = aroundFrame
            self.createGradientLayers()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    public func set(around aroundFrame: CGRect) {
        self.aroundFrame = aroundFrame
        self.removeGradientLayers()
        self.createGradientLayers()
    }
    
    private func removeGradientLayers() {
        if let sublayers = self.layer.sublayers {
            for layer in sublayers {
                if layer is CAGradientLayer {
                    layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    private func createGradientLayers() {
        let maxDistance = max(self.aroundFrame.minX, self.aroundFrame.minY, ScorecardUI.screenWidth - self.aroundFrame.maxX, ScorecardUI.screenHeight - self.aroundFrame.maxY)
        
        let superFrame = CGRect(x: self.aroundFrame.minX - maxDistance, y: self.aroundFrame.minY - maxDistance, width: self.aroundFrame.width + (2 * maxDistance), height: self.aroundFrame.height + (2 * maxDistance))
        
        // Top
        self.createGradientLayer(
            points: [
                CGPoint(x: superFrame.minX, y: superFrame.minY),
                CGPoint(x: superFrame.maxX, y: superFrame.minY),
                CGPoint(x: self.aroundFrame.maxX, y: self.aroundFrame.minY),
                CGPoint(x: self.aroundFrame.minX, y: self.aroundFrame.minY)],
            from: CGPoint(x: 0, y: 0),
            to:   CGPoint(x: 0, y: 1))
        
        // Left
        self.createGradientLayer(
            points: [
                CGPoint(x: superFrame.minX, y: superFrame.minY),
                CGPoint(x: superFrame.minX, y: superFrame.maxY),
                CGPoint(x: self.aroundFrame.minX, y: self.aroundFrame.maxY),
                CGPoint(x: self.aroundFrame.minX, y: self.aroundFrame.minY) ],
            from: CGPoint(x: 0, y: 0),
            to:   CGPoint(x: 1, y: 0))
        
        // Right
        self.createGradientLayer(
            points: [
                CGPoint(x: superFrame.maxX, y: superFrame.minY),
                CGPoint(x: superFrame.maxX, y: superFrame.maxY),
                CGPoint(x: self.aroundFrame.maxX, y: self.aroundFrame.maxY),
                CGPoint(x: self.aroundFrame.maxX, y: self.aroundFrame.minY)],
            from: CGPoint(x: 1, y: 0),
            to:   CGPoint(x: 0, y: 0))
        
        // Bottom
        self.createGradientLayer(
            points: [
                CGPoint(x: superFrame.minX, y: superFrame.maxY),
                CGPoint(x: superFrame.maxX, y: superFrame.maxY),
                CGPoint(x: self.aroundFrame.maxX, y: self.aroundFrame.maxY),
                CGPoint(x: self.aroundFrame.minX, y: self.aroundFrame.maxY)],
            from: CGPoint(x: 0, y: 1),
            to:   CGPoint(x: 0, y: 0))
        
 
    }
    
    private func createGradientLayer(points: [CGPoint], from startPoint: CGPoint, to endPoint: CGPoint) {
        let frame = self.surrounding(points: points)
        let color = UIColor.black
        let points = points.map{ $0.offsetBy(dx: -frame.minX, dy: -frame.minY)}
        let path = UIBezierPath()
        path.move(to: points.last!)
        for point in points {
            path.addLine(to: point)
        }
        path.close()
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = 0
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = frame
        gradientLayer.mask = shapeLayer
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.locations = [0, 0.95, 1]
        gradientLayer.colors = [color.withAlphaComponent(0.6).cgColor, color.withAlphaComponent(0.6).cgColor, color.withAlphaComponent(0.6).cgColor]
        self.layer.insertSublayer(gradientLayer, at: 0)
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
