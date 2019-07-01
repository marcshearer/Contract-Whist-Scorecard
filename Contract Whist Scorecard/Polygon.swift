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
    case point
}

class Polygon {
    
    static public func roundedMask(to view: UIView, definedBy points: [PolygonPoint], roundingFraction: CGFloat? = nil) {
        let shapeLayer = roundedShapeLayer(definedBy: points, roundingFraction: roundingFraction)
        view.layer.mask = shapeLayer
    }
   
    static public func roundedShape(in view: UIView, definedBy points: [PolygonPoint], strokeColor: UIColor = UIColor.black, fillColor: UIColor = UIColor.white, lineWidth: CGFloat = 1.0, roundingFraction: CGFloat? = nil) {
        let path = Polygon.roundedBezierPath(definedBy: points, roundingFraction: roundingFraction)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = lineWidth
        view.layer.addSublayer(shapeLayer)
    }
    
    static public func roundedShapeLayer(definedBy points: [PolygonPoint], roundingFraction: CGFloat? = nil) -> CAShapeLayer {
        
        let path = Polygon.roundedBezierPath(definedBy: points, roundingFraction: roundingFraction)
        
        return Polygon.shapeLayer(from: path)
    }
    
    static public func shapeLayer(from path: UIBezierPath) -> CAShapeLayer {
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        
        return shapeLayer
    }

    static public func roundedBezierPath(definedBy points: [PolygonPoint], roundingFraction: CGFloat? = nil) -> UIBezierPath {
        
        let roundingFraction = roundingFraction ?? 0.1
        
        var lines: [(start: CGPoint, end: CGPoint)] = []
        for index in 0...points.count-1 {
            lines.append(Polygon.partialLine(from: points[index].cgPoint, to: points[(index == points.count-1 ? 0 : index+1)].cgPoint, fraction: roundingFraction))
        }
        
        let path = UIBezierPath()
        if points.first!.pointType == .point {
            path.move(to: points.first!.cgPoint)
        } else {
            path.move(to: lines.first!.start)
        }
        for index in 0..<lines.count {
            let nextIndex = (index == points.count-1 ? 0 : index+1)
            let pointType = points[nextIndex].pointType
            if pointType == .point {
                path.addLine(to: points[nextIndex].cgPoint)
            } else {
                path.addLine(to: lines[index].end)
                if pointType == .halfRounded {
                    let point = CGPoint(x: lines[index].end.x + (points[nextIndex].x - lines[index].end.x) / 2.0, y: points[nextIndex].y)
                    path.addQuadCurve(to: point, controlPoint: point)
                } else {
                    path.addQuadCurve(to: lines[nextIndex].start, controlPoint: points[nextIndex].cgPoint)
                    if pointType == .insideRounded {
                        path.addLine(to: points[nextIndex].cgPoint)
                        path.addLine(to: lines[index].end)
                        path.addLine(to: points[nextIndex].cgPoint)
                        path.addLine(to: lines[nextIndex].start)
                    }
                }
            }
        }
        path.close()
        
        return path
    }
    
    static public func partialLine(from: CGPoint, to: CGPoint, fraction: CGFloat) -> (CGPoint, CGPoint) {
        return (Polygon.partialPoint(from: from, to: to, fraction: fraction), partialPoint(from: from, to: to, fraction: 1.0 - fraction))
    }
    
    static public func partialPoint(from: CGPoint, to: CGPoint, fraction: CGFloat) -> CGPoint {
        let newX = from.x + ((to.x - from.x) * fraction)
        let newY = from.y + ((to.y - from.y) * fraction)
        return CGPoint(x: newX, y: newY)
    }
}

class PolygonPoint {
    public var x: CGFloat
    public var y: CGFloat
    public var pointType: PolygonPointType
    
    init(x: CGFloat, y: CGFloat, pointType: PolygonPointType = .rounded) {
        self.x = x
        self.y = y
        self.pointType = pointType
    }
    
    var cgPoint: CGPoint {
        get {
            return CGPoint(x: self.x, y: self.y)
        }
    }
    
}
