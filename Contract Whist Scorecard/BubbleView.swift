//
//  BubbleView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class BubbleView: UIView {
    
    private var shadowView: UIView?
    private var label: UILabel?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isHidden = true
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.isHidden = true
    }
    
    func show(from view: UIView, message: String, size: CGFloat = 150, completion: (()->())? = nil) {
        self.frame = CGRect(x: view.frame.midX - (size / 2), y: max(50, view.frame.midY - size), width: size, height: size)
        self.alpha = 1
        if self.label == nil {
            self.shadowView = UIView(frame: CGRect(origin: CGPoint(), size: self.frame.size))
            self.toCircle(self.shadowView)
            self.shadowView?.backgroundColor = Palette.banner
            self.addSubview(self.shadowView!)
            self.label = UILabel(frame: CGRect(x: 5, y: 5, width: size - 10, height: size - 10))
            self.label?.backgroundColor = UIColor.clear
            self.label?.textColor = Palette.bannerText
            self.label?.numberOfLines = 0
            self.label?.adjustsFontSizeToFitWidth = true
            self.label?.textAlignment = .center
            self.shadowView?.addSubview(self.label!)
            self.addShadow(shadowOpacity: 0.5)
        }
        self.label?.text = message
        self.removeFromSuperview()
        view.addSubview(self)
        view.bringSubviewToFront(self)
        self.isHidden = false
        self.transform = CGAffineTransform(scaleX: 0, y: 0)
        Utility.animate(duration: 0.25,
            completion: {
                Utility.animate(duration: 0.2, afterDelay: 1.0,
                    completion: {
                        self.transform = CGAffineTransform(scaleX: 1, y: 1)
                        completion?()
                    },
                    animations: {
                        Utility.getActiveViewController()?.alertSound(sound: .lock)
                        self.frame = CGRect(x: view.frame.maxX, y: view.frame.maxY / 8, width: size, height: size)
                        self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                        self.alpha = 0
                    })
            },
            animations: {
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
    }
    
    func toCircle(_ view: UIView?) {
        view?.layer.cornerRadius = self.layer.bounds.height / 2
        view?.layer.masksToBounds = true
    }
    
}
