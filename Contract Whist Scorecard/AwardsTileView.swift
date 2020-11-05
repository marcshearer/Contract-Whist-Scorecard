//
//  AwardsTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class AwardsTileView: DashboardTileView, AwardCollectionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    internal override var helpId: String { "awards" }
    
    private var achieved: [Award] = []
    private var toAchieve: [Award] = []
    private var awardsTotal: Int = 0
    private var mode: AwardCellMode = .list
    private var awards = Awards()
    private var sections: Int!
    private var achievedSection: Int!
    private var toAchieveSection: Int!
    private var awardDetailView: AwardDetailView!
    private var tileColor: PaletteColor!
    private var shadow = true
    
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
        
        // Show detail for latest award
        if !self.achieved.isEmpty {
            self.showAwardDetail(award: self.achieved.first!, mode: .awarded, overrideTitle: "Latest Award")
        }
        
        // Set up colors
        if self.parentDashboardView?.parentViewController?.container != .none {
            self.tileColor = Palette.normal
            self.shadow = false
        } else {
            self.tileColor = Palette.buttonFace
            self.shadow = true
        }
        self.tileView.backgroundColor = self.tileColor.background
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
        
        if self.shadow {
            self.tileView.roundCorners(cornerRadius: 8.0)
            self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        }

    }
    
    // MARK: - Tile Delegate ================================================================= -
    
    internal func reloadData() {
        self.loadData(noCache: true)
        self.collectionView.reloadData()
    }
    
    internal func didRotate() {
        self.collectionViewFlowLayout.invalidateLayout()
    }
    
    internal func willDisappear() {
        self.awardDetailView?.hide()
        self.awardDetailView = nil
    }
    
    // MARK: - Dashboard Tile delegates ================================================= -
    
    private var gridHelpContext: String? // Used to avoid repeating the same message
    private var listHelpContext: String? // Used to avoid repeating the same message
    
    internal func addHelp(to helpView: HelpView) {
        
        helpView.add("The @*/Awarded@*/ section shows awards you have already achieved. The title shows the number of awards you have achieved compared to the total number that can be achieved.", views: [self.collectionView], callback: self.title, section: achievedSection, item: -1, horizontalBorder: 8)
        
        self.addButtons(helpView: helpView, section: achievedSection)
        
        helpView.add("The @*/For the Future@*/ section  shows awards you can still achieve in the future", views: [self.collectionView], callback: self.title, section: toAchieveSection, item: -1, horizontalBorder: 8)
        
        self.addButtons(helpView: helpView, section: toAchieveSection)
    }
    
    private func addButtons(helpView: HelpView, section: Int) {
        
        helpView.add("The @*/Grid Mode@*/ button switches the output to show the awards as a grid. This will allow more awards to be displayed.", views: [self.collectionView], callback: self.gridButton, section: section, item: -1, horizontalBorder: 4)
        
        helpView.add("The @*/List Mode@*/ button switches the output to show the awards as a list. This will display more information about each award", views: [self.collectionView], callback: self.listButton, section: section, item: -1, horizontalBorder: 4)
    }
    
    internal func title(item: Int, view: UIView) -> CGRect? {
        if let cell = view as? AwardCollectionHeader {
            return cell.titleLabel.frame
        } else {
            return nil
        }
    }
    
    internal func gridButton(item: Int, view: UIView) -> CGRect? {
        let helpContext = HelpView.helpContext
        if helpContext != self.gridHelpContext {
            if let cell = view as? AwardCollectionHeader {
                self.gridHelpContext = helpContext
                return cell.gridButton.frame
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    internal func listButton(item: Int, view: UIView) -> CGRect? {
        let helpContext = HelpView.helpContext
        if helpContext != self.listHelpContext {
            if let cell = view as? AwardCollectionHeader {
                self.listHelpContext = helpContext
                return cell.listButton.frame
            } else {
                return nil
            }
        } else {
            return nil
        }
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
                title = title + NSMutableAttributedString(" \(self.achieved.count)", color: self.tileColor.themeText)
                title = title + NSMutableAttributedString("/\(self.awardsTotal)", color: self.tileColor.themeText, font: UIFont.systemFont(ofSize: 12, weight: .light))
            } else {
                title = NSMutableAttributedString("For the Future")
            }
            header = AwardCollectionHeader.dequeue(collectionView, for: indexPath, delegate: self)
            header.bind(title: title, color: self.tileColor, section: indexPath.section, mode: self.mode, noAwards: indexPath.section == achievedSection && self.achieved.isEmpty)
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
        var mode: AwardDetailMode
        if indexPath.section == self.achievedSection {
            award = achieved[indexPath.row]
            mode = .awarded
        } else {
            award = toAchieve[indexPath.row]
            mode = .toBeAwarded
        }
        if !self.showAwardDetail(award: award, mode: mode) {
            // No view available in right panel - pop up
            if let viewController = self.parentDashboardView?.parentViewController, let parentView = viewController.view {
                self.awardDetailView = AwardDetailView(frame: parentView.frame)
                awardDetailView.set(backgroundColor: self.tileColor.background, textColor: self.tileColor.text)
                awardDetailView.set(awards: self.awards, playerUUID: Scorecard.settings.thisPlayerUUID, award: award, mode: mode)
                awardDetailView.show(from: parentView)
            }
        }
    }
    
    @discardableResult private func showAwardDetail(award: Award, mode: AwardDetailMode, overrideTitle: String? = nil) -> Bool {
        var shown = false
        if let viewController = self.parentDashboardView?.parentViewController {
            if let awardDetail = viewController.awardDetail {
                viewController.setRightPanel(title: (overrideTitle ?? mode.rawValue), caption: "")
                awardDetail.show(awards: self.awards, playerUUID: Scorecard.settings.thisPlayerUUID, award: award, mode: mode)
                shown = true
            }
        }
        return shown
    }
        
    // MARK: - Utility Routines ======================================================================== -
    
    private func loadData(noCache: Bool = false) {
        (self.achieved, self.toAchieve, self.awardsTotal) = awards.get(playerUUID: Scorecard.settings.thisPlayerUUID, noCache: noCache)
    }
}
