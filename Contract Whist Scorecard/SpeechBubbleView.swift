//
//  SpeechBubbleView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum SpeechBubbleArrowDirection {
    case up
    case down
    case left
    case right
    
    func offset(point: CGPoint, by: CGFloat) -> CGPoint {
        switch self {
        case .up:
            return CGPoint(x: point.x, y: point.y - by)
        case .down:
            return CGPoint(x: point.x, y: point.y + by)
        case .left:
            return CGPoint(x: point.x - by, y: point.y)
        case .right:
            return CGPoint(x: point.x + by, y: point.y)
        }
    }
}

class SpeechBubbleView : UIView {
    
    private var point: CGPoint!
    private var direction: SpeechBubbleArrowDirection?
    private var font: UIFont?
    private var arrowHeight: CGFloat = 16
    private var arrowWidth: CGFloat = 16 * 2 / 3
    private let textInset: CGFloat = 8
    private var parentViewController: ScorecardViewController!
    private var parentView: UIView!
    private var overrideWidth: CGFloat?
    
    private static let spacing: CGFloat = 16
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var label: UILabel!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadSpeechBubbleView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadSpeechBubbleView()
    }
    
    convenience init(from parentViewController: ScorecardViewController, in parentView: UIView) {
        self.init(frame: CGRect())
        self.parentViewController = parentViewController
        self.parentView = parentView
        parentView.addSubview(self)
        self.hide()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.label.textColor = Palette.buttonFace.text
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !self.isHidden {
            let direction = self.direction ?? (self.point.y < self.parentViewController.screenHeight / 2 ? .up : .down)
            let font = self.font ?? UIFont.systemFont(ofSize: 17)
            var width = self.overrideWidth ?? SpeechBubbleView.width()
            switch direction {
            case .left:
                width = min(width, self.parentViewController.screenWidth - self.point.x - SpeechBubbleView.spacing - self.arrowHeight)
            case .right:
                width = min(width, self.point.x - SpeechBubbleView.spacing - self.arrowHeight)
            default:
                break
            }
            
            let textHeight = self.label.attributedText?.labelHeight(width: width - (self.textInset * 2), font: font) ?? 100
            let height = textHeight + (2 * textInset)
            
            var minX: CGFloat
            var minY: CGFloat
            switch direction {
            case .up:
                minX = self.point.x - (width / 2)
                minY = self.point.y + self.arrowHeight
            case .down:
                minX = self.point.x - (width / 2)
                minY = self.point.y - height - self.arrowHeight
            case .left:
                minX = self.point.x + self.arrowHeight
                minY = self.point.y - (height / 2)
            case .right:
                minX = self.point.x - width - self.arrowHeight
                minY = self.point.y - (height / 2)
            }
            minX = min(max(SpeechBubbleView.spacing, minX), parentViewController.screenWidth - SpeechBubbleView.spacing - width)
            minY = min(max(SpeechBubbleView.spacing, minY), parentViewController.screenHeight - SpeechBubbleView.spacing - height)
            
            var labelFrame = CGRect(x: minX, y: minY, width: width, height: height)
            self.frame = self.superFrame(frame: labelFrame, point: point)
            self.contentView.frame = self.bounds
            labelFrame = self.parentView.convert(labelFrame, to: self)
            self.label.frame = labelFrame.grownBy(dx: -self.textInset, dy: -self.textInset)
            let localPoint = self.parentView.convert(self.point!, to: self)
            let shapeLayer = Polygon.speechBubble(frame: labelFrame, point: (self.arrowHeight == 0 ? nil : localPoint), strokeColor: Palette.buttonFace.background, fillColor: Palette.buttonFace.background, arrowWidth: self.arrowWidth)
            
            // Remove any previous sublayers
            if let sublayers = contentView.layer.sublayers {
                for layer in sublayers {
                    if layer is CAShapeLayer {
                        layer.removeFromSuperlayer()
                    }
                }
            }
            // Add this sublayer
            self.contentView.layer.insertSublayer(shapeLayer, at: 0)
        }
    }
    
    private func superFrame(frame: CGRect, point: CGPoint) -> CGRect {
        let minX = min(frame.minX, point.x)
        let minY = min(frame.minY, point.y)
        return CGRect(x: minX, y: minY, width: max(frame.maxX, point.x) - minX, height: max(frame.maxY, point.y) - minY)
    }
    
    public func height(_ text: NSAttributedString, font: UIFont? = nil, arrowHeight: CGFloat? = nil, width: CGFloat? = nil) -> CGFloat {
                
        let font = font ?? self.font ?? UIFont.systemFont(ofSize: 17)
        let width = (width == nil ? SpeechBubbleView.width() : min(375, width!) - (SpeechBubbleView.spacing * 2))
        
        let textHeight = text.labelHeight(width: width - (self.textInset - 2), font: font)
        
        return textHeight + (arrowHeight ?? self.arrowHeight) + (2 * textInset)
    }
    
    public static func width(availableWidth: CGFloat? = nil, minWidth: CGFloat = 190) -> CGFloat {
        return min(375, max(minWidth, availableWidth ?? UIScreen.main.bounds.width), UIScreen.main.bounds.height) - (SpeechBubbleView.spacing * 2)
    }
    
    public var labelFrame: CGRect { return self.convert(self.label.frame, to: self.parentView)}
    
    public func show(_ text: NSAttributedString, point: CGPoint? = nil, direction: SpeechBubbleArrowDirection? = nil, width: CGFloat? = nil, font: UIFont? = nil, arrowHeight: CGFloat? = nil, arrowWidth: CGFloat? = nil) {

        self.label.attributedText = text
        
        self.point = point
        self.direction = direction
        self.overrideWidth = (width == nil ? nil : min(375, width!) - (2 * SpeechBubbleView.spacing))
        self.font = font
        if let arrowHeight = arrowHeight { self.arrowHeight = arrowHeight }
        if let arrowWidth = arrowWidth { self.arrowWidth = arrowWidth }
        self.parentView.bringSubviewToFront(self)
        self.isHidden = false
        self.layoutSubviews()
    }
    
    public func hide() {
        self.isHidden = true
    }
     
    private func loadSpeechBubbleView() {
        Bundle.main.loadNibNamed("SpeechBubbleView", owner: self, options: nil)
        self.addSubview(contentView)
        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
}

