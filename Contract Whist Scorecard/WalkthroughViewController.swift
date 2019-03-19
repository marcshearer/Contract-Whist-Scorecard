//
//  WalkthroughViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class WalkthroughViewController: CustomViewController {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Local class variables
    var index = 0
    var heading = ""
    var imageFile = ""
    var content = ""
    var numberOfPages = 0
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet var headingTitle: UINavigationItem!
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var contentImageView: UIImageView!
    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet var forwardButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    
    @IBAction func nextPressed(sender: UIButton) {
        if index == pageControl.numberOfPages - 1 {
            dismiss(animated: true, completion: nil)
        } else {
            let pageViewController = parent as! WalkthroughPageViewController
            pageViewController.forward(index: index)
        }
    }
    
    @IBAction func finishPressed(sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
            
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()

        headingTitle.title = heading
        contentLabel.text = content
        contentImageView.image = UIImage(named: imageFile)
        pageControl.numberOfPages = numberOfPages
        pageControl.currentPage = index
        
        let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(WalkthroughViewController.swipeDetected as (WalkthroughViewController) -> () -> ()))
        swipeRecognizer.direction = .up
        self.view.addGestureRecognizer(swipeRecognizer)
    }
    
    @objc func swipeDetected() {
        dismiss(animated: true, completion: nil)
    }

}
