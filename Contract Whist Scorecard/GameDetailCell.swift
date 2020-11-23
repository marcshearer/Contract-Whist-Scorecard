//
//  GameDetailCell.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class GameDetailCell: UITableViewCell {
    @IBOutlet fileprivate weak var thumbnailView: ThumbnailView!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var scoreLabel: UILabel!
    
    override func awakeFromNib() {
        self.thumbnailView.set(frame: CGRect(x: 0, y: 16, width: 44, height: 44))
    }
    
    static public func heightForRow() -> CGFloat {
        return 60
    }
    
    public func set(playerName: String, playerThumbnail: Data?, score: Int?, textColor: UIColor = Palette.rightGameDetailPanel.text) {
        self.nameLabel.textColor = textColor
        self.scoreLabel.textColor = textColor
        self.thumbnailView.set(data: playerThumbnail, name: playerName)
        self.nameLabel.text = playerName
        self.scoreLabel.text = (score == nil ? "-" : "\(score!)")
    }
    
    public class func register(_ tableView: UITableView) {
        let nib = UINib(nibName: "GameDetailCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Game Detail")
    }
    
    public class func dequeue(_ tableView: UITableView, for indexPath: IndexPath) -> GameDetailCell {
        let view = tableView.dequeueReusableCell(withIdentifier: "Game Detail", for: indexPath) as! GameDetailCell
        return view
    }
}
