//
//  ImageButtonView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol ImageButtonDelegate {
    func imageButtonPressed(_ sender: ImageButton)
}

class ImageButton: UIView {
    
    @IBInspectable var image: UIImage!
    @IBInspectable var title: String!
    @IBInspectable var textColor: UIColor!
    @IBInspectable var cornerRadius: Double!
    @IBOutlet weak var delegate: ImageButtonDelegate?
    
    @IBOutlet weak var contentView: UIView!         
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    public var isEnabled: Bool {
        get {
            return self.contentView.isUserInteractionEnabled
        }
        set(newValue) {
            self.contentView.isUserInteractionEnabled = newValue
        }
    }
    
    override var alpha: CGFloat {
        get {
            return self.contentView.alpha
        }
        set(newValue) {
            self.imageView?.alpha = newValue
            self.titleLabel?.alpha = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadImageButtonView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadImageButtonView()
    }
    
    private func loadImageButtonView() {
        Bundle.main.loadNibNamed("ImageButton", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ImageButton.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func tapSelector(_ sender: Any) {
        self.delegate?.imageButtonPressed(self)
    }
    
    override func layoutSubviews() {
        self.titleLabel.text = self.title
        self.imageView.image = self.image
        self.contentView.backgroundColor = self.backgroundColor
        self.titleLabel.textColor = self.textColor
        if let cornerRadius = CGFloat(self.cornerRadius) {
            self.contentView.layer.cornerRadius = cornerRadius
        }
    }
    
}
