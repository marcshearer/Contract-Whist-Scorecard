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
    
    private static let spacing: CGFloat = 16
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var labelContainerView: UIView!
    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var labelContainerViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var labelContainerViewBottomConstraint: NSLayoutConstraint!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadSpeechBubbleView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadSpeechBubbleView()
    }
    
    convenience init(in view: UIView) {
        self.init(frame: CGRect())
        view.addSubview(self)
        self.hide()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.label.textColor = Palette.buttonFace.text
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !self.isHidden {
            let direction = self.direction ?? (self.point.y < ScorecardUI.screenHeight / 2 ? .up : .down)
            let font = self.font ?? UIFont.systemFont(ofSize: 17)
            var width = SpeechBubbleView.width
            switch direction {
            case .left:
                width = min(width, ScorecardUI.screenWidth - self.point.x - SpeechBubbleView.spacing - self.arrowHeight)
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
            minX = min(max(SpeechBubbleView.spacing, minX), ScorecardUI.screenWidth - SpeechBubbleView.spacing - width)
            minY = min(max(SpeechBubbleView.spacing, minY), ScorecardUI.screenHeight - SpeechBubbleView.spacing - height)
            
            var labelFrame = CGRect(x: minX, y: minY, width: width, height: height)
            self.frame = self.superFrame(frame: labelFrame, point: point)
            self.contentView.frame = self.bounds
            labelFrame = self.superview!.convert(labelFrame, to: self)
            self.label.frame = labelFrame.grownBy(dx: -self.textInset, dy: -self.textInset)
            let localPoint = self.superview!.convert(self.point!, to: self)
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
    
    public func height(_ text: NSAttributedString, font: UIFont? = nil, arrowHeight: CGFloat? = nil) -> CGFloat {
                
        let font = font ?? self.font ?? UIFont.systemFont(ofSize: 17)
        let width = SpeechBubbleView.width
        
        let textHeight = text.labelHeight(width: width - (self.textInset - 2), font: font)
        
        return textHeight + (arrowHeight ?? self.arrowHeight) + (2 * textInset)
    }
    
    public static var width: CGFloat {
        return min(375, UIScreen.main.bounds.width) - (SpeechBubbleView.spacing * 2)
    }
    
    public func show(_ text: NSAttributedString, point: CGPoint? = nil, direction: SpeechBubbleArrowDirection? = nil, font: UIFont? = nil, arrowHeight: CGFloat? = nil, arrowWidth: CGFloat? = nil) {

        self.label.attributedText = text
        
        if let point = point { self.point = point }
        if let direction = direction { self.direction = direction }
        if let font = font { self.font = font }
        if let arrowHeight = arrowHeight { self.arrowHeight = arrowHeight }
        if let arrowWidth = arrowWidth { self.arrowWidth = arrowWidth }
        self.superview?.bringSubviewToFront(self)
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

