//
//  PlayerSelectionView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/10/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

@objc public protocol PlayerSelectionViewDelegate {
    
    func didSelect(playerMO: PlayerMO)
    
    @objc optional func resizeView()
        
}

class PlayerSelectionView: UIView, PlayerViewDelegate, UIGestureRecognizerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet public weak var delegate: PlayerSelectionViewDelegate!
    @IBOutlet private weak var parent: ScorecardViewController!
    
    private var playerList: [PlayerMO]!
    private var thumbnailWidth: CGFloat = 0.0
    private var thumbnailHeight: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private var labelHeight: CGFloat = 30.0
    private var interRowSpacing:CGFloat = 10.0
    private let collectionSpacing: CGFloat = 10.0
    private var collectionInset: CGFloat = 10.0
    private var lastSize: CGSize!
    private var textColor: UIColor!
    private var addButtonColor: UIColor = Palette.normal.themeText
    private var addButton = false
    private var updateBeforeSelect = false
    private var offset = 0
    
    public var collectionWidth: CGFloat {
        return self.collectionView.frame.width
    }
    
    public var cellWidth: CGFloat {
        return self.thumbnailWidth
    }
    
    public var cellHeight: CGFloat {
        return self.thumbnailHeight
    }
    
    // MARK: - IB Outlets ============================================================================== -
       
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var topInset: NSLayoutConstraint!
    @IBOutlet private weak var bottomInset: NSLayoutConstraint!
    @IBOutlet private weak var leadingInset: NSLayoutConstraint!
    @IBOutlet private weak var trailingInset: NSLayoutConstraint!

    // MARK: - Constructors ============================================================================== -
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadPlayerSelectionView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = frame
        self.loadPlayerSelectionView()
        self.awakeFromNib()
    }
    
    convenience init(parent: ScorecardViewController, frame: CGRect, interRowSpacing: CGFloat = 10.0) {
        self.init(frame: frame)
        self.parent = parent
        self.interRowSpacing = interRowSpacing
        self.awakeFromNib()
    }
    
    internal override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        self.collectionView.layoutIfNeeded()
        self.setSize()
    }
    
    public func set(players: [PlayerMO], addButton: Bool = false, updateBeforeSelect: Bool = false, scrollEnabled: Bool = false, collectionViewInsets: UIEdgeInsets? = nil, contentInset: UIEdgeInsets? = nil) {
        self.addButton = addButton
        self.offset = (addButton ? 1 : 0)
        self.playerList = players
        self.collectionView.isScrollEnabled = scrollEnabled
        if let collectionViewInsets = collectionViewInsets {
            self.topInset.constant = collectionViewInsets.top
            self.bottomInset.constant = collectionViewInsets.bottom
            self.leadingInset.constant = collectionViewInsets.left
            self.trailingInset.constant = collectionViewInsets.right
            self.collectionView.contentInset = contentInset ?? UIEdgeInsets(top: 10.0 - collectionViewInsets.top, left: 0, bottom: 0, right: 0)
        }
        UIView.performWithoutAnimation {
            self.collectionView.reloadData()
        }
    }
    
    public func set(textColor: UIColor) {
        self.textColor = textColor
        self.collectionView.reloadData()
    }
    
    public func set(addButtonColor: UIColor) {
        self.addButtonColor = addButtonColor
        self.collectionView.reloadData()
    }
    
    public func set(size: CGSize? = nil) {
        UIView.performWithoutAnimation {
            self.setSize(size: size)
        }
    }
    
    public func getHeightFor(items: Int) -> CGFloat {
        let frame = self.frame
        let height = frame.height
        if height == 0 {
            self.frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 500)
        }
        self.layoutIfNeeded()
        
        let availableWidth = self.collectionWidth + 10.0
        
        let cellsAcross = Int(availableWidth / (self.cellWidth + 10.0))
        let cellsDown = (items + cellsAcross - 1) / cellsAcross
        
        self.frame = frame
        
        return (CGFloat(cellsDown) * (self.cellHeight + self.interRowSpacing)) - self.interRowSpacing + (2 * self.collectionInset)
    }
    
    private func loadPlayerSelectionView() {
        Bundle.main.loadNibNamed("PlayerSelectionView", owner: self, options: nil)
        self.addSubview(contentView)
        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.collectionView.register(PlayerSelectionCell.self, forCellWithReuseIdentifier: "Available")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        self.textColor = Palette.normal.text
    }
    
    private func setSize(size: CGSize? = nil) {
        let viewSize = size ?? self.frame.size
        if self.lastSize != viewSize {
            // Setup sizes of thumbnail and a row in the collection
            if viewSize.height > 0 {
                let thumbnailSize = SelectionViewController.thumbnailSize(from: self.parent, labelHeight: self.labelHeight, marginWidth: self.collectionInset, spacing: collectionSpacing)
                self.thumbnailWidth = thumbnailSize.width
                self.thumbnailHeight = thumbnailSize.height
                self.rowHeight = self.thumbnailHeight + self.interRowSpacing
            }
            lastSize = viewSize
        }
    }

    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return (playerList?.count ?? 0) + offset
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return interRowSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: PlayerSelectionCell
        
        // Available players
        
        let playerNumber = indexPath.row + 1 - offset
        
        // Create player view
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Available", for: indexPath) as! PlayerSelectionCell
        if cell.thumbnailView == nil {
            cell.thumbnailView = ThumbnailView(frame: CGRect(x: 0.0, y: 0.0, width: self.thumbnailWidth, height: self.thumbnailHeight))
            cell.addSubview(cell.thumbnailView)
        }
        if playerNumber == 0 {
            cell.thumbnailView.set(name: "", alpha: 1.0)
            cell.thumbnailView.set(imageName: "big plus white", tintColor: self.addButtonColor)
            cell.thumbnailView.set(backgroundColor: UIColor.clear)
        } else {
            cell.thumbnailView.set(imageName: nil)
            cell.thumbnailView.set(playerMO: playerList[playerNumber-1], nameHeight: labelHeight, diameter: self.thumbnailWidth)
        }
        cell.thumbnailView.set(textColor: self.textColor)

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.row - self.offset
        if index < 0 {
            // Add button
            self.showSelectPlayers()
        } else {
            // Player selected
            self.delegate?.didSelect(playerMO: playerList[index])
        }
    }
    
    // MARK: - Create players ============================================================ -
    
    private func showSelectPlayers() {
        _ = SelectPlayersViewController.show(from: self.parent, completion: { (playerList) in
            if let playerList = playerList {
                if playerList.count > 0 {
                    self.createPlayers(newPlayers: playerList)
                }
            }
        })
    }
    
    private func createPlayers(newPlayers: [PlayerDetail]) {
        
        for newPlayerDetail in newPlayers {
            if let playerMO = newPlayerDetail.playerMO {
                
                if newPlayers.count != 1 || self.updateBeforeSelect {
                    
                    // Add to player list if not there already
                    if self.playerList.firstIndex(where: { $0.playerUUID! == newPlayerDetail.playerUUID } ) == nil {
                        
                        var playerIndex: Int! = self.playerList.firstIndex(where: {($0.name! > newPlayerDetail.name)})
                        if playerIndex == nil {
                            // Insert at end
                            playerIndex = self.playerList.count
                        }
                        self.collectionView.performBatchUpdates({
                            self.playerList.insert(playerMO, at: playerIndex)
                            self.collectionView.insertItems(at: [IndexPath(row: playerIndex + self.offset, section: 0)])
                        })
                    }
                }
                
                // Auto-select if necessary
                if newPlayers.count == 1 {
                    self.delegate?.didSelect(playerMO: playerMO)
                }
            }
        }
        // Resize view if necessary
        if newPlayers.count > 1 || self.updateBeforeSelect {
            self.delegate?.resizeView?()
        }
    }
       
    // MARK: - Image download handlers =================================================== -
    
    public func updatePlayer(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            if let playerList = self.playerList,
               let availableIndex = playerList.firstIndex(where: {($0.objectID == objectID)}) {
                // Found it - reload the cell
                self.collectionView.reloadItems(at: [IndexPath(row: availableIndex, section: 0)])
            }
        }
    }
}

class PlayerSelectionCell: UICollectionViewCell {
    
    fileprivate var thumbnailView: ThumbnailView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.thumbnailView.frame = CGRect(origin: CGPoint(), size: self.frame.size)
    }
}

