//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    public var scorecard: Scorecard!
    public var round: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let hand: Hand = self.scorecard.dealHistory[self.round]?.hands[tableView.tag - 1]
        for handSuit in hand.
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        <#code#>
    }
}

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var label: UILabel!
    
}
