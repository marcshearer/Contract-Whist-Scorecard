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
    case smoothQuadRounded
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
    
    static public func roundedShapeLayer(in view: UIView? = nil, definedBy points: [PolygonPoint], strokeColor: UIColor? = nil, fillColor: UIColor? = nil, lineWidth: CGFloat? = nil, radius: CGFloat? = nil) -> CAShapeLayer {
        
        let path = Polygon.roundedBezierPath(definedBy: points, radius: radius)
        
        let shapeLayer = Polygon.shapeLayer(from: path, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth)
        
        if let view = view {
            view.layer.insertSublayer(shapeLayer, at: 0)
        }
        
        return shapeLayer
    }
    
    static public func shapeLayer(from path: UIBezierPath, strokeColor: UIColor? = nil, fillColor: UIColor? = nil, lineWidth: CGFloat? = nil) -> CAShapeLayer {
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = lineWidth ?? 1.0
        shapeLayer.fillColor = fillColor?.cgColor ?? UIColor.white.cgColor
        shapeLayer.strokeColor = strokeColor?.cgColor ?? UIColor.black.cgColor
        
        return shapeLayer
    }

    static public func roundedBezierPath(definedBy points: [PolygonPoint], radius: CGFloat? = nil, insideRadius: CGFloat? = nil) -> UIBezierPath {
        
        let radius = radius ?? 3.5
        let insideRadius = insideRadius ?? radius
        
        let path = CGMutablePath()
        path.move(to: partialPoint(from: points[0].cgPoint, to: points[1].cgPoint, fraction: 0.5))
        for index in 1...points.count {
            let radius = points[index % points.count].radius ?? radius
            let previous = points[(index + points.count - 1) % points.count].cgPoint
            let current = points[index % points.count].cgPoint
            let extendedPoint = points[index % points.count].extendedPoint ?? CGPoint(x: current.x + radius, y: current.y)
            let next = points[(index + 1) % points.count].cgPoint
            
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
                
            case .smoothQuadRounded:
                path.addLine(to: partialPoint(from: current, to: previous, distance: radius))
                path.addQuadCurve(to: extendedPoint, control: current)
                
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
    
    enum ShapeType {
        case arrowRight
        case hexagon
        case arrowLeft
    }

    static public func angledBannerContinuationMask(view: UIView, frame: CGRect, type: ShapeType, arrowWidth: CGFloat) {
        
        let width = frame.width
        let height = frame.height
        let minX = frame.minX
        let minY = frame.minY
        
        var points: [CGPoint] = []
        switch type {
        case .arrowLeft:
            points.append(CGPoint(x: minX + width, y: minY))
            points.append(CGPoint(x: minX + width, y: minY + height))
            points.append(CGPoint(x: minX + arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX, y: minY))
        case .arrowRight:
            points.append(CGPoint(x: minX, y: minY))
            points.append(CGPoint(x: minX, y: minY + height))
            points.append(CGPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width, y: minY))
        case .hexagon:
            points.append(CGPoint(x: minX, y: minY))
            points.append(CGPoint(x: minX + arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width, y: minY))
        }
        
        var lines: [(start: CGPoint, end: CGPoint)] = []
        for index in 0...points.count-1 {
            lines.append(Polygon.partialLine(from: points[index], to: points[(index == points.count-1 ? 0 : index+1)], fraction: 0.1))
        }
        
        let path = UIBezierPath()
        if ScorecardUI.screenWidth <= 500 {
            path.move(to: points[0])
        } else {
            path.move(to: CGPoint(x: points[0].x - (lines[2].end.x - lines[2].start.x) * 0.1, y: points[3].y))
            path.addQuadCurve(to: lines[0].start, controlPoint: points[0])
        }
        if type == . hexagon {
            path.addLine(to: lines[0].end)
            path.addQuadCurve(to: lines[1].start, controlPoint: points[1])
        } else {
            path.addLine(to: points[1])
        }
        path.addLine(to: lines[1].end)
        path.addQuadCurve(to: lines[2].start, controlPoint: points[2])
        path.addLine(to: lines[2].end)
        path.addQuadCurve(to: CGPoint(x: points[3].x + (lines[2].end.x - lines[2].start.x) * 0.1, y: points[3].y), controlPoint: points[3])
        path.addLine(to: points[0])
        path.close()
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        
        view.layer.mask = shapeLayer
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
    
    static public func hexagonFrame(in view: UIView, frame: CGRect? = nil, strokeColor: UIColor, fillColor: UIColor = UIColor.clear, arrowWidth: CGFloat? = nil, lineWidth: CGFloat = 2.0, radius: CGFloat? = nil) -> CAShapeLayer {
        var points: [PolygonPoint] = []
        let frame = frame ?? CGRect(origin: CGPoint(), size: view.frame.size)
        let arrowWidth = arrowWidth ?? frame.height / 3.0
        let minX = frame.minX + (lineWidth / 2.0)
        let maxX = frame.maxX - (lineWidth / 2.0)
        let minY = frame.minY + (lineWidth / 2.0)
        let maxY = frame.maxY - (lineWidth / 2.0)
        points.append(PolygonPoint(x: minX, y: frame.midY))
        points.append(PolygonPoint(x: minX + arrowWidth, y: minY))
        points.append(PolygonPoint(x: maxX - arrowWidth, y: minY))
        points.append(PolygonPoint(x: maxX, y: frame.midY))
        points.append(PolygonPoint(x: maxX - arrowWidth, y: maxY))
        points.append(PolygonPoint(x: minX + arrowWidth, y: maxY))
        return Polygon.roundedShapeLayer(in: view, definedBy: points, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, radius: radius)
    }
    
    public class func speechBubble(frame: CGRect, point: CGPoint, strokeColor: UIColor, fillColor: UIColor = UIColor.clear, lineWidth: CGFloat = 2.0, radius: CGFloat = 10.0, arrowWidth: CGFloat? = nil) -> CAShapeLayer {
        var insert: Int
        var anchor: CGPoint
        var points: [PolygonPoint] = []
        points.append(PolygonPoint(x: frame.minX, y: frame.minY, pointType: .rounded))
        points.append(PolygonPoint(x: frame.maxX, y: frame.minY, pointType: .rounded))
        points.append(PolygonPoint(x: frame.maxX, y: frame.maxY, pointType: .rounded))
        points.append(PolygonPoint(x: frame.minX, y: frame.maxY, pointType: .rounded))
        if point.y < frame.minY {
            insert = 0
            anchor = CGPoint(x: point.x, y: frame.minY)
        } else if point.x > frame.maxX {
            insert = 1
            anchor = CGPoint(x: frame.maxX, y: point.y)
        } else if point.x < frame.minX {
            insert = 3
            anchor = CGPoint(x: frame.minX, y: point.y)
        } else {
            insert = 2
            anchor = CGPoint(x: point.x, y: frame.maxY)
        }
        var arrow: [PolygonPoint] = []
        let start = points[insert].cgPoint
        let anchorDistance = start.distance(to: anchor)
        let arrowHeight = anchor.distance(to: point)
        let arrowWidth = arrowWidth ?? arrowHeight / 3
        let edgePointType: PolygonPointType = (arrowWidth == 0 ? .point : .quadRounded)
        
        arrow.append(PolygonPoint(origin: Polygon.partialPoint(from: start, to: anchor, distance: anchorDistance - (arrowWidth / 2)), pointType: edgePointType))
        arrow.append(PolygonPoint(origin: point, pointType: .point))
        arrow.append(PolygonPoint(origin: Polygon.partialPoint(from: start, to: anchor, distance: anchorDistance + (arrowWidth / 2)), pointType: edgePointType))
        points.insert(contentsOf: arrow, at: insert + 1)
        return Polygon.roundedShapeLayer(definedBy: points, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, radius: radius)
    }
}

class PolygonPoint {
    public var x: CGFloat
    public var y: CGFloat
    public var pointType: PolygonPointType
    public var radius: CGFloat?
    public var extendedPoint: CGPoint?
    
    init(x: CGFloat, y: CGFloat, pointType: PolygonPointType? = nil, radius: CGFloat? = nil, controlPoint: CGPoint? = nil) {
        self.x = x
        self.y = y
        self.pointType = pointType ?? .rounded
        self.radius = radius
        self.extendedPoint = controlPoint
    }
    
    convenience init(origin: CGPoint, pointType: PolygonPointType = .rounded, radius: CGFloat? = nil, controlPoint: CGPoint? = nil) {
        self.init(x: origin.x, y: origin.y, pointType: pointType, radius: radius, controlPoint: controlPoint)
    }
    
    var cgPoint: CGPoint {
        get {
            return CGPoint(x: self.x, y: self.y)
        }
    }
    
}
