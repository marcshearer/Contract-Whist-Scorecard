//
//  Polygon.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

enum PolygonPointType {
    case rounded
    case halfRounded
    case insideRounded
    case quadRounded
    case point
}

enum PolygonTransform {
    case reflectCenterHorizontal
    case reflectCenterVertical
}

class Polygon {
    
    static public func roundedMask(to view: UIView, definedBy points: [PolygonPoint], radius: CGFloat? = nil) {
        let shapeLayer = roundedShapeLayer(definedBy: points, radius: radius)
        view.layer.mask = shapeLayer
    }
    
    static public func roundedShape(in view: UIView, definedBy points: [PolygonPoint], strokeColor: UIColor = UIColor.black, fillColor: UIColor = UIColor.white, lineWidth: CGFloat = 1.0, radius: CGFloat? = nil, transform: PolygonTransform? = nil) {
            _ = Polygon.roundedShapePath(in: view, definedBy: points, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, radius: radius, transform: transform)
        }
   
    static public func roundedShapePath(in view: UIView, definedBy points: [PolygonPoint], strokeColor: UIColor = UIColor.black, fillColor: UIColor = UIColor.white, lineWidth: CGFloat = 1.0, radius: CGFloat? = nil, transform: PolygonTransform? = nil) -> UIBezierPath {
        let insideRadius = (radius == nil ? nil : min(lineWidth * 1.3, radius!))
        
        let path = Polygon.roundedBezierPath(definedBy: points, radius: radius, insideRadius: insideRadius)
        if let transform = transform {
            switch transform {
            case .reflectCenterHorizontal:
                path.apply(CGAffineTransform(translationX: -(view.bounds.width / 2.0), y: 0.0))
                path.apply(CGAffineTransform(scaleX: -1, y: 1))
                path.apply(CGAffineTransform(translationX: (view.bounds.width / 2.0), y: 0.0))
            case .reflectCenterVertical:
                path.apply(CGAffineTransform(translationX: 0.0, y: (view.bounds.height / 2.0)))
                path.apply(CGAffineTransform(scaleX: 1, y: -1))
                path.apply(CGAffineTransform(translationX: 0.0, y: (view.bounds.height / 2.0)))
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = lineWidth
        view.layer.addSublayer(shapeLayer)
        
        return path
        
    }
    
    static public func roundedShapeLayer(definedBy points: [PolygonPoint], radius: CGFloat? = nil) -> CAShapeLayer {
        
        let path = Polygon.roundedBezierPath(definedBy: points, radius: radius)
        
        return Polygon.shapeLayer(from: path)
    }
    
    static public func shapeLayer(from path: UIBezierPath) -> CAShapeLayer {
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        
        return shapeLayer
    }

    static public func roundedBezierPath(definedBy points: [PolygonPoint], radius: CGFloat? = nil, insideRadius: CGFloat? = nil) -> UIBezierPath {
        
        let radius = radius ?? 3.5
        let insideRadius = insideRadius ?? radius
        
        let path = CGMutablePath()
        path.move(to: partialPoint(from: points[0].cgPoint, to: points[1].cgPoint, fraction: 0.5))
        for index in 1...points.count {
            let previous = points[(index + points.count - 1) % points.count].cgPoint
            let current = points[index % points.count].cgPoint
            let next = points[(index + 1) % points.count].cgPoint
            let radius = points[index % points.count].radius ?? radius
            
            switch points[index % points.count].pointType {
            case .point:
                path.addLine(to: current)
                
            case .halfRounded:
                let angle = Polygon.angle(at: current, from: previous, to: next)
                let dx = ((radius / sin(angle)) - radius)
                let dy = dx * tan(angle) * (previous.y > next.y ? -1 : 1)
                let point1 = CGPoint(x: current.x - dx, y: current.y - dy)
                let point2 = CGPoint(x: current.x - dx, y: current.y)
                path.addArc(tangent1End: point1, tangent2End: point2, radius: radius)
                
            case .rounded:
                path.addArc(tangent1End: current, tangent2End: next, radius: radius)
                
            case .quadRounded:
                path.addLine(to: partialPoint(from: current, to: previous, distance: radius))
                path.addQuadCurve(to: partialPoint(from: current, to: next, distance: radius), control: current)
                
            case .insideRounded:
                path.addArc(tangent1End: current, tangent2End: next, radius: insideRadius)
                path.addLine(to: current)
                path.addLine(to: self.partialPoint(from: current, to: previous, fraction: 0.5))
                path.addLine(to: current)
                path.addLine(to: self.partialPoint(from: current, to: next, fraction: 0.5))
            }
        }
        path.closeSubpath()
        let bezierPath = UIBezierPath(cgPath: path)
        
        return bezierPath
    }
    
    static private func radius(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let x = point2.x - point1.x
        let y = point1.y - point2.y
        return (pow(x, 2) + pow(y,2) / (2 * x)).squareRoot()
    }
    
    static public func partialPoint(from: CGPoint, to: CGPoint, fraction: CGFloat) -> CGPoint {
        let newX = from.x + ((to.x - from.x) * fraction)
        let newY = from.y + ((to.y - from.y) * fraction)
        return CGPoint(x: newX, y: newY)
    }
    
    static public func partialPoint(from: CGPoint, to: CGPoint, distance: CGFloat) -> CGPoint {
        let x = to.x - from.x
        let y = to.y - from.y
        let totalDistance = (pow(x,2) + pow(y,2)).squareRoot()
        return partialPoint(from: from, to: to, fraction: distance/totalDistance)
    }
    
    static public func partialLine(from: CGPoint, to: CGPoint, fraction: CGFloat) -> (CGPoint, CGPoint) {
        return (Polygon.partialPoint(from: from, to: to, fraction: fraction), partialPoint(from: from, to: to, fraction: 1.0 - fraction))
    }
    
    static public func angle(from: CGPoint, to: CGPoint) -> CGFloat {
        return atan2((from.y - to.y), (from.x-to.x))
    }
    
    static public func angle(at: CGPoint, from: CGPoint, to: CGPoint) -> CGFloat {
        let angle1 = Polygon.angle(from: from, to: at)
        let angle2 = Polygon.angle(from: to, to: at)
        var angle = abs(angle1 - angle2)
        if angle > CGFloat.pi {
            angle = (2 * CGFloat.pi) - angle
        }
        return angle
    }
    
}

class PolygonPoint {
    public var x: CGFloat
    public var y: CGFloat
    public var pointType: PolygonPointType
    public var radius: CGFloat?
    
    init(x: CGFloat, y: CGFloat, pointType: PolygonPointType = .rounded, radius: CGFloat? = nil) {
        self.x = x
        self.y = y
        self.pointType = pointType
        self.radius = radius
    }
    
    var cgPoint: CGPoint {
        get {
            return CGPoint(x: self.x, y: self.y)
        }
    }
    
}
