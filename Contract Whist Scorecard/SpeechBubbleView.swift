//
//  SpeechBubbleView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum SpeechBubbleArrowDirection: CGFloat {
    case up = 1
    case down = -1
}

class SpeechBubbleView : UIView {
    
    private var point: CGPoint!
    private var direction: SpeechBubbleArrowDirection?
    private var font: UIFont?
    private var arrowHeight: CGFloat = 16
    private var arrowWidth: CGFloat = 16 * 2 / 3
    private let spacing: CGFloat = 16
    private let textInset: CGFloat = 8
    
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
            let font = self.font ?? UIFont.systemFont(ofSize: 17)
            let width = min(375, self.superview!.frame.width) - (self.spacing * 2)
            let textHeight = self.label.attributedText?.labelHeight(width: width - (self.textInset * 2), font: font) ?? 100
            let height = textHeight + arrowHeight + (2 * textInset)
            let direction = self.direction ?? (self.point.y < ScorecardUI.screenHeight / 2 ? .up : .down)
            let minX = min(max(self.spacing, self.point.x - (width / 2)), self.superview!.frame.maxX - self.spacing - width)
            let minY = self.point.y - (direction == .up ? 0 : height)
            let textOffsetY = (direction == .up ? self.arrowHeight : 0)
            self.frame = CGRect(x: minX, y: minY, width: width, height: height)
            self.contentView.frame = self.bounds
            let point = self.superview!.convert(self.point!, to: self)
            self.labelContainerViewTopConstraint.constant = (direction == .up ? self.arrowHeight : 0)
            self.labelContainerViewBottomConstraint.constant = (direction == .up ? 0 : self.arrowHeight)
            let shapeLayer = Polygon.speechBubble(frame: (CGRect(x: 0, y: textOffsetY, width: width, height: height - self.arrowHeight)), point: point, strokeColor: Palette.buttonFace.background, fillColor: Palette.buttonFace.background, arrowWidth: self.arrowWidth)
            
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
    
    public func height(_ text: NSAttributedString, font: UIFont? = nil, arrowHeight: CGFloat? = nil) -> CGFloat {
                
        let font = font ?? self.font ?? UIFont.systemFont(ofSize: 17)
        let width = min(375, UIScreen.main.bounds.width) - (self.spacing * 2)
        
        let textHeight = text.labelHeight(width: width - (self.textInset - 2), font: font)
        
        return textHeight + (arrowHeight ?? self.arrowHeight) + (2 * textInset)
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

