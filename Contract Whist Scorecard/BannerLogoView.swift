//
//  BannerLogoView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class BannerLogoView : UIView {
    
    @IBOutlet private weak var contentView: UIView!
    
    @IBInspectable public var strokeColor: UIColor = Palette.bannerText
    @IBInspectable public var fillColor: UIColor = Palette.banner
    @IBInspectable public var lineWidth: CGFloat = 0.0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadBannerLogoView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadBannerLogoView()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let sublayers = self.contentView.layer.sublayers {
            for (index, layer) in sublayers.enumerated() {
                if layer is CAShapeLayer {
                    self.contentView.layer.sublayers!.remove(at: index)
                }
            }
        }
        
        let width = self.frame.width
        let lineWidth = (self.lineWidth == 0 ? width / 24 : self.lineWidth)
        let height = self.frame.height - lineWidth
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -lineWidth/2, y: -lineWidth/2))
        path.addLine(to: CGPoint(x: width/3, y: height))
        path.addLine(to: CGPoint(x: width/2, y: height/2))
        path.addLine(to: CGPoint(x: 2*width/3, y: height))
        path.addLine(to: CGPoint(x: width+lineWidth/2, y: -lineWidth/2))
        path.close()
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = lineWidth
        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        
        self.contentView.layer.insertSublayer(shapeLayer, at: 0)
    }
    
    private func loadBannerLogoView() {
        Bundle.main.loadNibNamed("BannerLogoView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
