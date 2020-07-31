//
//  AwardsTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class AwardsTileView: UIView, DashboardTileDelegate, AwardCollectionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
            
    private var achieved: [Award] = []
    private var toAchieve: [Award] = []
    private var awardsTotal: Int = 0
    private var mode: AwardCellMode = .list
    private var awards = Awards()
    private var sections: Int!
    private var achievedSection: Int!
    private var toAchieveSection: Int!
    
    private var spacing: CGFloat = 10.0
    private var nameHeight: CGFloat = 12.0
    private var sectionInsets = UIEdgeInsets(top: 12, left: 12, bottom: 20, right: 12)
    
    @IBInspectable private var viewMode: String {
        get {
            return self.mode.rawValue
        }
        set(mode) {
            self.mode = AwardCellMode(rawValue: mode) ?? .list
        }
    }
    @IBInspectable private var awarded: Bool = true
    @IBInspectable private var notAwarded: Bool = true
    @IBInspectable private var headings: Bool = true
    @IBInspectable private var styleChoice: Bool = true

    @IBOutlet private weak var parentDashboardView: DashboardView?

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tileView: UIView!
    
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadAwardsTileView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadAwardsTileView()
    }
            
    private func loadAwardsTileView() {
        Bundle.main.loadNibNamed("AwardsTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Default view colors
        self.defaultViewColors()
        
        // Register collection view cells
        AwardCollectionCell.register(self.collectionView, modes: .grid, .list)
        AwardCollectionHeader.register(self.collectionView)
        
        // Load data
        self.loadData()
     }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Setup sections
        self.sections = 0
        if self.awarded {
            self.achievedSection = self.sections
            self.sections += 1
        }
        if self.notAwarded {
            self.toAchieveSection = self.sections
            self.sections += 1
        }
        
        // Configure collection view
        self.collectionViewFlowLayout.sectionHeadersPinToVisibleBounds = true
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
        
        self.tileView.roundCorners(cornerRadius: 8.0)
        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))

    }
    
    // MARK: - Tile Delegate ================================================================= -
    
    internal func reloadData() {
        self.loadData(noCache: true)
        self.collectionView.reloadData()
    }
    
    internal func didRotate() {
        self.collectionViewFlowLayout.invalidateLayout()
    }
    
    // MARK: - Award collection delegate ================================================================== -
    
    internal func changeMode(to mode: AwardCellMode, section: Int) {
        if self.mode != mode {
            
            // Try to save the first cell currently displayed
            var current: IndexPath?
            let visible = self.collectionView.indexPathsForVisibleItems
            if !visible.isEmpty {
                let sorted = visible.sorted(by: {$0.section < $1.section || ($0.section == $1.section && $0.item < $1.item)})
                
                // Now find the first cell which is not hidden behind the header
                for item in sorted {
                    if let layout = self.collectionView.collectionViewLayout.layoutAttributesForItem(at: item) {
                        let headerHeight = self.collectionView(self.collectionView, layout: self.collectionView.collectionViewLayout, referenceSizeForHeaderInSection: item.section).height
                        if layout.frame.maxY - self.collectionView.contentOffset.y > headerHeight {
                            current = item
                            break
                        }
                    }
                }
            }
            
            self.mode = mode
            self.collectionViewFlowLayout.invalidateLayout()
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            
            if let current = current {
                // Position at bottom of header
                if let layout = self.collectionView.collectionViewLayout.layoutAttributesForItem(at: current) {
                    let headerHeight = self.collectionView(self.collectionView, layout: self.collectionView.collectionViewLayout, referenceSizeForHeaderInSection: current.section).height
                    self.collectionView.contentOffset = CGPoint(x: 0, y: layout.frame.minY - headerHeight)
                } else {
                    self.collectionView.scrollToItem(at: current, at: .top, animated: true)
                }
            }
        }
    }
    
    // MARK: - Collection View delegates ================================================================== -
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sections
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return AwardCollectionHeader.sizeForHeader(collectionView, section: section, noAwards: (section == achievedSection && self.achieved.isEmpty))
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var header = AwardCollectionHeader()
        
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            var title: NSMutableAttributedString
            if indexPath.section == achievedSection {
                title = NSMutableAttributedString("Awarded")
                title = title + NSMutableAttributedString(" \(self.achieved.count)", color: Palette.banner)
                title = title + NSMutableAttributedString("/\(self.awardsTotal)", color: Palette.banner, font: UIFont.systemFont(ofSize: 12, weight: .light))
            } else {
                title = NSMutableAttributedString("For the Future")
            }
            header = AwardCollectionHeader.dequeue(collectionView, for: indexPath, delegate: self)
            header.bind(title: title, section: indexPath.section, mode: self.mode, noAwards: indexPath.section == achievedSection && self.achieved.isEmpty)
        default:
            break
        }
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == achievedSection {
            return achieved.count
        } else {
            return toAchieve.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return self.sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return AwardCollectionCell.sizeForCell(collectionView, mode: self.mode, across: (ScorecardUI.landscapePhone() ? 6 : 3), spacing: self.spacing, labelHeight: self.nameHeight, sectionInsets: self.sectionInsets)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: AwardCollectionCell
        
        cell = AwardCollectionCell.dequeue(collectionView, for: indexPath, mode: self.mode)
        if indexPath.section == self.achievedSection {
            cell.bind(award: achieved[indexPath.row])
        } else {
            cell.bind(award: toAchieve[indexPath.row], alpha: 0.5)
        }
        cell.tag = (1000000 * indexPath.section) + indexPath.row
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var award: Award
        if let parentView = self.parentDashboardView?.parentViewController?.view {
            if indexPath.section == self.achievedSection {
                award = achieved[indexPath.row]
            } else {
                award = toAchieve[indexPath.row]
            }
            let awardView = AwardDetailView(frame: parentView.frame)
            awardView.set(awards: self.awards, playerUUID: Scorecard.settings.thisPlayerUUID, award: award, mode: (indexPath.section == achievedSection ? .awarded : .toBeAwarded), backgroundColor: Palette.buttonFace, textColor: Palette.buttonFaceText)
            awardView.show(from: parentView)
        }
    }
        
    // MARK: - Utility Routines ======================================================================== -
    
    private func loadData(noCache: Bool = false) {
        (self.achieved, self.toAchieve, self.awardsTotal) = awards.get(playerUUID: Scorecard.settings.thisPlayerUUID, noCache: noCache)
    }
    
    private func defaultViewColors() {
        self.tileView.backgroundColor = Palette.buttonFace
    }
}
