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
    
    @objc optional func didSelect(playerMO: PlayerMO)
        
}

class PlayerSelectionView: UIView, PlayerViewDelegate, UIGestureRecognizerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public var delegate: PlayerSelectionViewDelegate!
    
    private var playerList: [PlayerMO]!
    private var thumbnailWidth: CGFloat = 0.0
    private var thumbnailHeight: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private var labelHeight: CGFloat = 30.0
    private var interRowSpacing:CGFloat = 10.0
    public let collectionInset: CGFloat = 4.0
    private let collectionSpacing: CGFloat = 10.0
    private var lastSize: CGSize!
    private var textColor: UIColor!
    
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
    
    // MARK: - Constructors ============================================================================== -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = frame
        self.setSize()
        self.loadPlayerSelectionView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setSize()
        self.loadPlayerSelectionView()
    }
    
    convenience init(frame: CGRect, playerList: [PlayerMO]? = nil, interRowSpacing: CGFloat = 10.0) {
        self.init(frame: frame)
        self.playerList = playerList
        self.interRowSpacing = interRowSpacing
    }
    
    public func set(players: [PlayerMO]) {
        self.playerList = players
        self.collectionView.reloadData()
    }
    
    public func set(textColor: UIColor) {
        self.textColor = textColor
        self.collectionView.reloadData()
    }
    
    private func loadPlayerSelectionView() {
        Bundle.main.loadNibNamed("PlayerSelectionView", owner: self, options: nil)
        self.addSubview(contentView)
        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.collectionView.register(PlayerSelectionCell.self, forCellWithReuseIdentifier: "Available")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        self.textColor = Palette.text
    }
    
    private func setSize() {
        if self.lastSize != self.frame.size {
            // Setup sizes of thumbnail and a row in the collection
            if self.frame.height > 0 {
                let thumbnailSize = SelectionViewController.thumbnailSize(view: self, labelHeight: self.labelHeight, marginWidth: self.collectionInset, spacing: collectionSpacing)
                self.thumbnailWidth = thumbnailSize.width
                self.thumbnailHeight = thumbnailSize.height
                self.rowHeight = self.thumbnailHeight + self.interRowSpacing
            }
            lastSize = self.frame.size
        }
    }

    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return playerList?.count ?? 0
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
        
        let playerNumber = indexPath.row + 1
        
        // Create player view
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Available", for: indexPath) as! PlayerSelectionCell
        if cell.thumbnailView == nil {
            cell.thumbnailView = ThumbnailView(frame: CGRect(x: 0.0, y: 0.0, width: self.thumbnailWidth, height: self.thumbnailHeight))
            cell.addSubview(cell.thumbnailView)
        }
        cell.thumbnailView.set(playerMO: playerList[playerNumber-1], nameHeight: labelHeight, diameter: self.thumbnailWidth)
        cell.thumbnailView.set(textColor: self.textColor)

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.delegate?.didSelect?(playerMO: playerList[indexPath.row])
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            if let availableIndex = self.playerList.firstIndex(where: {($0.objectID == objectID)}) {
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

