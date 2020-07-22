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
        self.loadData()
        self.collectionView.reloadData()
    }
    
    internal func willRotate() {
        self.collectionViewFlowLayout.invalidateLayout()
    }
    
    // MARK: - Award collection delegate ================================================================== -
    
    internal func changeMode(to mode: AwardCellMode, section: Int) {
        if self.mode != mode {
            self.mode = mode
            self.collectionViewFlowLayout.invalidateLayout()
            self.collectionView.reloadData()
            // self.collectionView.scrollToItem(at: IndexPath(item: 0, section: section), at: .centeredVertically, animated: true)
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
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
            header = AwardCollectionHeader.dequeue(collectionView, for: indexPath, delegate: self)
            header.bind(title: (indexPath.section == achievedSection ? "Awarded" : "For the Future"), section: indexPath.section, mode: self.mode, noAwards: indexPath.section == achievedSection && self.achieved.isEmpty ? true : false)
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
            awardView.set(awards: self.awards, playerUUID: Scorecard.settings.thisPlayerUUID, award: award, mode: (indexPath.section == achievedSection ? .awardDate : .awardLevels), backgroundColor: Palette.buttonFace, textColor: Palette.buttonFaceText)
            awardView.show(from: parentView)
        }
    }
        
    // MARK: - Utility Routines ======================================================================== -
    
    private func loadData() {
        (self.achieved, self.toAchieve) = awards.get(playerUUID: Scorecard.settings.thisPlayerUUID)
    }
    
    private func defaultViewColors() {
        self.tileView.backgroundColor = Palette.buttonFace
    }
}
