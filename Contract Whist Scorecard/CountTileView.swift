//
//  CountTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class CountTileView: UIView {
    
    private enum Period: Int, CaseIterable {
        case day = 0
        case week = 1
        case month = 2
        case year = 3
    }
    
    @objc public enum CountValue: Int {
        case gamesInPeriod = 1
    }
    
    private var detailType: DashboardDetailType = .history
    private var value: CountValue = .gamesInPeriod
    
    @IBInspectable private var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable private var countValue: Int {
        get {
            return self.value.rawValue
        }
        set(value) {
            self.value = CountValue(rawValue: value) ?? .gamesInPeriod
        }
    }
    @IBInspectable private var personal: Bool = true
    @IBInspectable private var title: String = ""
    @IBInspectable private var caption: String = ""
       
    @IBOutlet private weak var dashboardDelegate: DashboardActionDelegate?
    
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
    }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.dashboardDelegate?.action(view: detailType)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.tileView.backgroundColor = Palette.buttonFace
        self.titleLabel.textColor = Palette.textTitle
        self.countLabel.textColor = Dashboard.color(detailView: detailType)
        self.typeButton.tintColor = Dashboard.color(detailView: detailType)
        self.typeButton.setImage(Dashboard.image(detailView: detailType), for: .normal)
        self.captionLabel.textColor = Palette.text
        
        self.titleLabel.text = self.title
        self.getValue()
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
                
        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
    }
    
    private func getValue() {
        switch self.value {
        case .gamesInPeriod:
            var startOf: [Period:Date] = [:]
            var count: [Period:Int] = [:]
            startOf[.day] = Calendar.current.startOfDay(for: Date())
            startOf[.week] = Calendar.current.date(bySetting: .weekday, value: 1, of: startOf[.day]!)!.addingTimeInterval(-6*24*60*60)
            startOf[.month] = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: startOf[.day]!))
            startOf[.year] = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: startOf[.day]!))
            let history = History(playerUUID: Scorecard.settings.thisPlayerUUID, since: startOf[.year]!)
            for (index, historyGame) in history.games.enumerated() {
                for period in Period.allCases {
                    if historyGame.datePlayed >= startOf[period]! {
                        count[period] = index + 1
                    }
                }
            }
            var showPeriod = Period.year
            var showValue = 0
            for period in Period.allCases {
                if ((count[period] ?? 0) >= 1) && showValue <= (count[.day] ?? 0) {
                    showPeriod = period
                    showValue = count[period] ?? 0
                }
            }
            self.countLabel.text = "\(showValue)"
            self.captionLabel.text = "\(showValue == 1 ? "Game" : "Games") \((showPeriod == .day ? "today" : "this \(showPeriod)"))"
        }
    }
}
