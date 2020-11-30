//
//  Test.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class TestViewController: ScorecardViewController {
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func create() -> TestViewController {
        
        let storyboard = UIStoryboard(name: "TestViewController", bundle: nil)
        let testViewController = storyboard.instantiateViewController(withIdentifier: "TestViewController") as! TestViewController
        
        return testViewController
        
    }
    
    class public func show(from viewController: ScorecardViewController) {
        
        let testViewController = TestViewController.create()
        
        viewController.present(testViewController, animated: true, container: .mainRight, completion: nil)
        
    }
}
