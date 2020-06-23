//
//  CountTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class CountTileView: UIView {
    
    private var actionView: DashboardDetailView = .history
    private var value: DashboardValue = .gamesInPeriod
    
    @IBInspectable private var action: Int {
        get {
            return self.actionView.rawValue
        }
        set(actionView) {
            self.actionView = DashboardDetailView(rawValue: actionView) ?? .history
        }
    }
    @IBInspectable private var countValue: Int {
        get {
            return self.value.rawValue
        }
        set(value) {
            self.value = DashboardValue(rawValue: value) ?? .gamesInPeriod
        }
    }
    @IBInspectable private var personal: Bool = true
    @IBInspectable private var title: String = ""
    @IBInspectable private var caption: String = ""
       
    @IBOutlet private weak var delegate: DashboardActionDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tileView: UIView!
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var countLabel: UITextField!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var typeButton: ClearButton!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadTitleBarView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadTitleBarView()
    }
            
    private func loadTitleBarView() {
        Bundle.main.loadNibNamed("CountTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(CountTileView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
        
        self.layoutSubviews()
        self.setNeedsLayout()
    }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.delegate?.action(view: actionView)
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
        
        let count = self.delegate?.getValue(value: self.value, personal: self.personal) ?? 0
        
        self.titleLabel.text = self.title
        self.countLabel.text = "\(count)"
        self.captionLabel.text = caption
         
        self.tileView.backgroundColor = Palette.buttonFace
        self.titleLabel.textColor = Palette.textTitle
        self.countLabel.textColor = Dashboard.color(detailView: actionView)
        self.typeButton.tintColor = Dashboard.color(detailView: actionView)
        self.typeButton.setImage(Dashboard.image(detailView: actionView), for: .normal)
        self.captionLabel.textColor = Palette.text

        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
    }
}

class VerticalAlignedLabel: UILabel {

    override func drawText(in rect: CGRect) {
        var newRect = rect
        switch contentMode {
        case .top:
            newRect.size.height = sizeThatFits(rect.size).height
        case .bottom:
            let height = sizeThatFits(rect.size).height
            newRect.origin.y += rect.size.height - height
            newRect.size.height = height
        default:
            ()
        }

        super.drawText(in: newRect)
    }
}
