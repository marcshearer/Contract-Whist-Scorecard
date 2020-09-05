//
//  ConfettiView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/10/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class ConfettiView: UIView {
    
    private var velocities = [180, 200, 150, 250]
    private var imageNames = ["spade", "heart", "diamond", "club"]
    private var colors: [UIColor] = [Palette.confetti]
    
    private let confettiViewEmitterLayer = CAEmitterLayer()
    
    // MARK: - Initializers
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required public init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    
    private func commonInit() {
        
        self.setupBaseLayer()
        self.setupConfettiEmitterLayer()
        
    }
    
    public func start() {
        self.confettiViewEmitterLayer.beginTime = CACurrentMediaTime()
        self.confettiViewEmitterLayer.emitterCells = generateConfettiEmitterCells()
        self.layer.addSublayer(confettiViewEmitterLayer)
    }
    
    public func stop(immediate: Bool = false) {
        if immediate {
            self.confettiViewEmitterLayer.emitterCells = []
        } else {
            self.confettiViewEmitterLayer.birthRate = 0
        }
    }
    
    // MARK: - Setup Layers
    private func setupBaseLayer() {
        self.layer.backgroundColor = UIColor.clear.cgColor
    }
    
    private func setupConfettiEmitterLayer() {
        self.confettiViewEmitterLayer.emitterSize = CGSize(width: bounds.width, height: 2)
        self.confettiViewEmitterLayer.emitterShape = .line
        self.confettiViewEmitterLayer.emitterPosition = CGPoint(x: bounds.width / 2, y: -2.0)
        self.confettiViewEmitterLayer.renderMode = .additive
    }
    
    // MARK: - Generator
    private func generateConfettiEmitterCells() -> [CAEmitterCell] {
        var cells = [CAEmitterCell]()
                
        for index in 0..<10 {
            let cell = CAEmitterCell()
            cell.color = nextColor(i: index)
            cell.contents = nextImage(i: index)
            cell.birthRate = 4.0
            cell.lifetime = 20.0
            cell.lifetimeRange = 0
            cell.scale = 0.2
            cell.scaleRange = 0.15
            cell.velocity = -CGFloat(randomVelocity)
            cell.velocityRange = 0
            cell.emissionLongitude = 0.0
            cell.emissionRange = 0.5
            cell.spin = 3.5
            cell.spinRange = 1
        
            cells.append(cell)
        }
        
        return cells
    }
    
    // MARK: - Helpers
    var randomNumber: Int {
        return Int(arc4random_uniform(UInt32(velocities.count)))
    }
    
    var randomVelocity: Int {
        return velocities[randomNumber]
    }
    
    private func nextColor(i: Int) -> CGColor {
        return colors[i % colors.count].cgColor
    }
    
    private func nextImage(i: Int) -> CGImage? {
        let image = UIImage(named: imageNames[i % imageNames.count])
        return image?.cgImage
    }
}
