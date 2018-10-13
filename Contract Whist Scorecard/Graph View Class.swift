//
//  Graph View.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

protocol GraphDetailDelegate: class {
    func graphDetail(drillRef: Any)
}

class GraphView: UIView {

    private struct Dataset {
        var values: [CGFloat]
        var weight: CGFloat
        var color: UIColor
        var gradient: Bool
        var pointSize: CGFloat
        var tag: Int
        var xAxisLabels: [String]!
        var drillRef: [Any]!
    }
    
    public enum Position {
        case left
        case right
    }
    
    private struct Label {
        var text: String
        var value: CGFloat
        var position: Position
        var color: UIColor
    }
    
    // Class variables
    private var datasets: [Dataset] = []
    private var yAxisLabels: [Label] = []
    private var yAxisLimit: Int!
    private var title: String!
    private var leftMaxLen: Int = 0
    private var rightMaxLen: Int = 0
    private var bottomMaxLen: Int = 0
    
    // Detail delegate
    public weak var detailDelegate: GraphDetailDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if !ScorecardUI.phoneSize(){
            self.layer.cornerRadius = 10
            self.layer.masksToBounds = true
        }
    }
    
    init() {
        super.init(frame: .zero)
        if !ScorecardUI.phoneSize(){
            self.layer.cornerRadius = 10
            self.layer.masksToBounds = true
        }
    }
    
    public func reset() {
        datasets = []
        yAxisLabels = []
        yAxisLimit = nil
        title = nil
        leftMaxLen = 0
        rightMaxLen = 0
        
    }

    public func addDataset(values: [CGFloat], weight: CGFloat = 3.0, color: UIColor = UIColor.white, gradient: Bool = false, pointSize: CGFloat = 0.0, tag: Int = 0, xAxisLabels: [String]! = nil, drillRef: [Any]! = nil) {
        self.datasets.append(Dataset(values: values, weight: weight, color: color, gradient: gradient, pointSize: pointSize, tag: tag, xAxisLabels: xAxisLabels, drillRef: drillRef))
        if xAxisLabels != nil {
            for label in xAxisLabels {
                bottomMaxLen = max(label.count, bottomMaxLen)
            }
        }
    }
    
    public func addTitle(title: String) {
        self.title = title
    }
    
    public func addYaxisLabel(text: String, value: CGFloat, position: Position, color: UIColor = UIColor.white) {
        yAxisLabels.append(Label(text: text, value: value, position: position, color: color))
        if position == .left {
            leftMaxLen = max(text.count, leftMaxLen)
        } else {
            rightMaxLen = max(text.count, rightMaxLen)
        }
    }
    
    internal override func draw(_ rect: CGRect) {
        let height:CGFloat = self.frame.height
        let width:CGFloat = self.frame.width
        var leftMargin: CGFloat = 20.0 + (8.0 * CGFloat(leftMaxLen))
        let rightMargin: CGFloat = 20.0 + (8.0 * CGFloat(rightMaxLen))
        let topBorder:CGFloat = (title == nil ? 50 : 70)
        let bottomBorder:CGFloat = 20 + (8.0 * CGFloat(bottomMaxLen))
        let graphHeight = height - topBorder - bottomBorder
        var maxValue: CGFloat!
        let context = UIGraphicsGetCurrentContext()
        let colors = [UIColor.white.cgColor, ScorecardUI.totalColor.cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: colorLocations)
        
        // Adjust left margin for angled x axis labels
        if bottomMaxLen > 0 {
            leftMargin = max(leftMargin, (CGFloat(bottomMaxLen) * 5.0))
        }
        
        // Calculate x position
        let columnXPoint = { (dataset: Dataset, column: Int) -> CGFloat in
            let xScale: CGFloat = (width - leftMargin - rightMargin - 4) /
                CGFloat((dataset.values.count - 1))
            //Calculate gap between points
            var x:CGFloat = CGFloat(column) * xScale
            x += leftMargin + 2
            return x
        }
        
        // Calculate y position
        let columnYPoint = { (graphPoint: CGFloat) -> CGFloat in
            var y:CGFloat = CGFloat(graphPoint) /
                CGFloat(maxValue) * graphHeight
            y = graphHeight + topBorder - y  // Flip the graph
            return y
        }
  
        if datasets.count > 0 {
            
            // Remove any previously created labels etc - assume that anything with a tag can go
            for view in self.subviews {
                if view.tag != 0 {
                    view.removeFromSuperview()
                }
            }
        
            // Choose line and fill colours
            UIColor.white.setFill()
            UIColor.white.setStroke()
            
            // Set maximum value
            maxValue = datasets[0].values.max()
            
            // Draw x-axis
            let xAxis = UIBezierPath()
            xAxis.move(to: CGPoint(x: columnXPoint(datasets[0], 0), y: columnYPoint(0)))
            xAxis.addLine(to: CGPoint(x: columnXPoint(datasets[0], datasets[0].values.count-1), y: columnYPoint(0)))
            xAxis.stroke()
            
            // Draw y-axis
            let yAxis = UIBezierPath()
            yAxis.move(to: CGPoint(x: columnXPoint(datasets[0], 0), y: columnYPoint(0)))
            yAxis.addLine(to: CGPoint(x: columnXPoint(datasets[0], 0), y: columnYPoint(maxValue)))
            yAxis.stroke()
            
            for dataset in datasets {
                // Draw the dataset line
                let xScale: CGFloat = (width - leftMargin - rightMargin - 4) /
                    CGFloat((dataset.values.count - 1))
                let graphPath = UIBezierPath()
                graphPath.lineWidth = dataset.weight
                dataset.color.setFill()
                dataset.color.setStroke()
                
                // Go to start of line
                graphPath.move(to: CGPoint(x: columnXPoint(dataset, 0),
                                              y: columnYPoint(dataset.values[0])))
                
                // Move to each point
                if dataset.values.count > 1 {
                    // Add points for each item in the graphPoints array
                    // at the correct (x, y) for the point
                    for i in 1...dataset.values.count-1 {
                        let nextPoint = CGPoint(x: columnXPoint(dataset, i),
                                                y: columnYPoint(dataset.values[i]))
                        graphPath.addLine(to: nextPoint)
                    }
                    
                    graphPath.stroke()
                }
                
                if dataset.gradient {
                    // Add in the gradient
                    
                    context!.saveGState()
                    
                    // Create gradient
                    let clippingPath = graphPath.copy() as! UIBezierPath
                    
                    // Add lines to the copied path to complete the clip area
                    clippingPath.addLine(to: CGPoint(
                        x: columnXPoint(dataset, dataset.values.count - 1),
                        y: height))
                    clippingPath.addLine(to: CGPoint(
                        x: columnXPoint(dataset, 0),
                        y: height))
                    clippingPath.close()
                    
                    //Add the clipping path to the context
                    clippingPath.addClip()
                    
                    // Add the gradient
                    let startPoint = CGPoint(x: leftMargin, y: columnYPoint(maxValue))
                    let endPoint = CGPoint(x: leftMargin, y: columnYPoint(0))
                    
                    context!.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions(rawValue: 0))
                    
                    context!.restoreGState()
                    
                }
                
                if dataset.pointSize > 0.0 {
                    // Draw on data points
                    for i in 0...dataset.values.count-1 {
                        var point = CGPoint(x: columnXPoint(dataset, i), y: columnYPoint(dataset.values[i]))
                        point.x -= dataset.pointSize/2
                        point.y -= dataset.pointSize/2
                        
                        let circle = UIBezierPath(ovalIn:
                            CGRect(origin: point,
                                   size: CGSize(width: dataset.pointSize, height: dataset.pointSize)))
                        circle.fill()
                    }
                }
                if dataset.drillRef != nil && detailDelegate != nil {
                    // Create a button at each point for detail drill
                    for i in 0...dataset.values.count-1 {
                        let button = UIButton(frame: CGRect(x: columnXPoint(dataset, i) - (xScale / 2),
                                                              y: columnYPoint(dataset.values[i]) - 50,
                                                              width: xScale,
                                                              height: 100))
                        button.tag = (dataset.tag * Int(1e6)) + i
                        button.addTarget(self, action: #selector(GraphView.detailButtonPressed(_:)), for: UIControl.Event.touchUpInside)
                        self.addSubview(button)
                    }
                }
            
                if dataset.xAxisLabels != nil && dataset.xAxisLabels.count != 0 {
                    for i in 0...dataset.xAxisLabels.count - 1 {
                        let label = UILabel(frame: CGRect(x: columnXPoint(dataset, i) - (CGFloat(bottomMaxLen) * 5.5),
                                                          y: columnYPoint(0) + 1 + (CGFloat(bottomMaxLen) * 4.0) - (xScale / 2.0),
                                                          width: CGFloat(bottomMaxLen) * 8.0,
                                                          height: xScale))
                        label.text = dataset.xAxisLabels[i]
                        label.font = UIFont.systemFont(ofSize: 16)
                        label.adjustsFontSizeToFitWidth = true
                        label.textColor = UIColor.white
                        label.textAlignment = .left
                        label.transform = CGAffineTransform(rotationAngle: -7.0 * (CGFloat.pi / 20))
                        self.addSubview(label)
                    }
                }
            }
        }
        
        if self.title != nil {
            let label = UILabel(frame: CGRect(x: leftMargin + 10, y: 10, width: width - leftMargin - rightMargin - 20, height: topBorder - 30))
            label.text = self.title
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 24)
            label.adjustsFontSizeToFitWidth = true
            label.textColor = UIColor.white
            label.tag = 1
            self.addSubview(label)
        }
        
        
        if self.yAxisLabels.count != 0 {
            var x: CGFloat
            var margin: CGFloat
            
            for yAxisLabel in yAxisLabels {
                if yAxisLabel.position == .left {
                    x = 4
                    margin = leftMargin
                } else {
                    x = width - rightMargin + 4
                    margin = rightMargin
                }
                let label = UILabel(frame: CGRect(x: x, y: columnYPoint(yAxisLabel.value)-8, width: margin - 8, height: 16))
                label.text = yAxisLabel.text
                label.font = UIFont.systemFont(ofSize: 16)
                label.adjustsFontSizeToFitWidth = true
                label.textColor = yAxisLabel.color
                if yAxisLabel.position == .left {
                    label.textAlignment = .right
                } else {
                    label.textAlignment = .left
                }
                label.tag = 1
                self.addSubview(label)
            }
        }
    }
    
    @objc internal func detailButtonPressed(_ button: UIButton) {
        let datasetTag = Int(button.tag / Int(1e6))
        let dataset = datasets.index(where: {$0.tag == datasetTag} )
        if dataset != nil {
            let drillTag = datasets[dataset!].drillRef[button.tag % Int(1e6)]
            detailDelegate?.graphDetail(drillRef: drillTag)
        }
    }
    
    public class func defaultViewRect(size: CGSize = UIScreen.main.bounds.size) -> CGRect {
        var width: CGFloat
        var height: CGFloat
        
        let screenWidth = size.width
        let screenHeight = size.height
        
        if screenWidth < screenHeight {
            // Portrait
            width = screenWidth * 0.95
            height = width * screenWidth / screenHeight
        } else {
            // Landscape
            width = screenHeight * 0.95
            height = width * screenHeight / screenWidth
        }
        
        return CGRect(x: (screenWidth - width) / 2.0, y: (screenHeight - height) / 2.0, width: width, height: height)
    }
}
