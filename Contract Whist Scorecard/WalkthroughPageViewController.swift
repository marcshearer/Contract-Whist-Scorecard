//
//  WalkthroughPageViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class WalkthroughPageViewController: UIPageViewController, UIPageViewControllerDataSource {

    // MARK: - Class Properties ======================================================================== -
    
    // Local class variables
    var details: [(title: String, image: String, tabletImage: String, compact: String, verbose: String)] =
                        [("Get Started", "get started screen", "",
                            "On entry to the app (until you create some players) you will be greeted by the 'Get Started' screen. Type in a Sync Group if you want to use iCloud sharing and if this is an existing group you can then download any existing players in this group",
                            ""),
                         ("Welcome", "welcome screen", "welcome ipad screen",
                          "The welcome screen gives you access to settings, statistics, history and high scores. Tap 'New Game' to start playing. If you re-start the app, click 'Resume Game' to continue a game in progress",
                          ""),
                        ("Settings", "settings screen", "",
                            "Settings change how the app behaves. You can change how the dealer is shown, change the length and style of the game and choose if you want to sync over iCloud",
                            "Settings change the behaviour of the app. You can choose how (if at all) the dealer is highlighted on the Scorecard.shared. You can switch on a special rule where you get a bonus of 10 points if you win a trick with a two. You can choose between the dealer starting the bidding or the next player. You can choose how many hands to play in a game. You can choose if stats can  be shared between devices over iCloud. The player's unique identifier field is used to link players across devices. These could for example be playerUUID addresses or any other unique identifiers that are consistent across devices"),
                        ("Players", "players screen", "players ipad screen",
                            "Players shows you a summary of each player. Tap a player for more detail or click 'Select' to choose several players to compare. You can also sync with iCloud using the 🔄 button",
                            "Players shows you a summary of each player. Tap a player for more detail or click 'Select' to choose several players to compare. You can also sync with iCloud using the 🔄 button if you have enabled synchronisation in settings. You also need to be logged into iCloud on your device"),
                        ("Statistics", "statistics screen", "statistics ipad screen",
                            "Statistics shows detailed stats for the players you have selected. Tap a player to see more detail. Tap a column header to sort by that value. Tap twice to reverse sort. You can also sync with iCloud using the 🔄 button",
                            "Statistics shows detailed stats for the players you have selected. Tap a player to see more detail. Tap a column header to sort by that value. Tap twice to reverse sort. You can also sync with iCloud using the 🔄 button if you have enabled synchronisation in settings"),
                        ("Player Detail", "player detail screen", "",
                            "Amend the player's name and unique ID or tap the camera to add a photo for them. You can amend / remove an existing photo by tapping it. Also you can see all their stats",
                            "Amend the player's name and unique ID or tap the camera to add a photo for them. You can amend / remove an existing photo by tapping it. Also you can see all their stats. You can delete a player by pressing the 'Delete' button"),
                        ("History", "history screen", "history ipad screen",
                         "History shows a list of all games played on this device. If you are using iCloud sync it will include games from all devices in your Sync Group. Tap a game to see more detail. Tap a column header to sort by that value. Tap twice to reverse sort. You can also sync with iCloud using the 🔄 button",
                         ""),
                        ("History Detail", "history detail screen", "",
                         "This allows you to see the detail of the game including the scores, number of bids made and number of tricks won with a two for each player. You can also see where and when the game took place. You can correct the game location if necessary",
                         ""),
                        ("High Scores", "high scores screen", "",
                            "High scores shows the top 3 players for total scores, number of bids made in a game, and number of twos made in a game (if you are playing with bonus for winning with a two enabled)",
                            ""),
                        ("Player Selection", "selection screen", "selection ipad screen",
                            "Selection allows you to choose who is playing in the game. Tap players at the top of the screen to move them in to the selected area. Press and hold a selected player to drag and resequence. Tap the '+' disc to create a new player",
                            ""),
                        ("Game Preview", "game preview screen", "game preview ipad screen",
                            "Game preview shows you the selected players and allows you to set the dealer either randomly (cut for dealer) or manually (by pressing next dealer). Click on the arrow to start the game",
                            ""),
                        ("Scorecard", "scorepad screen", "scorepad ipad screen",
                            "The scorecard shows you progress in the game so far. If you make your contract the score for that round is shown in red. A small icon shows if you won with a two",
                            ""),
                        ("Game Location", "location screen", "",
                         "If you have enabled game location in settings then you will be asked to confirm the current location when you enter the first round of the game. You can enter the location manually if WiFi is not available",
                         ""),
                        ("Score Entry", "entry screen", "",
                            "This is the main score entry screen. Tap on the numbers to enter players scores. Use the arrows to move back and forwards or the summary button (the dark gray rectangle in the footer) to see the round summary",
                            ""),
                        ("Round Summary", "round summary screen", "",
                            "Once all bids are entered a round summary is shown. This is designed to be visible while you play the hand and it reminds you of the trump suit and each player's bid",
                            ""),
                        ("Game Summary", "game summary screen", "",
                            "At the end of the game a summary is shown. High scores and personal bests (for total points) are flagged. Tap a row to see all the high scores or the previous personal best",
                            "")]
    var numberOfPages = 0
    
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberOfPages = details.count
        
        // Set the data source to itself
        dataSource = self
        
        // Create the first walkthrough screen
        if let startingViewController = contentViewController(at: 0) {
            setViewControllers([startingViewController], direction: .forward, animated: true, completion: nil)
        }
    }
    
    // MARK: - PageView Overrides ===================================================================== -
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        var index = (viewController as! WalkthroughViewController).index
        if index == 0 {
            dismiss(animated: true, completion: nil)
        } else {
            index -= 1
        }
        
        return contentViewController(at: index)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        let walkthroughViewController = viewController as! WalkthroughViewController
        
        var index = walkthroughViewController.index
        
        if index == numberOfPages - 1 {
            dismiss(animated: true, completion: nil)
        } else {
            index += 1
        }
        return contentViewController(at: index)
    }
    
    func contentViewController(at index: Int) -> WalkthroughViewController? {
        if index < 0 || index >= details.count {
            return nil
        }
        
        // Create a new view controller and pass suitable data.
        let storyboard = UIStoryboard(name: "WalkthroughViewController", bundle: nil)
        if let pageViewController = storyboard.instantiateViewController(withIdentifier: "WalkthroughViewController") as? WalkthroughViewController {
            
            pageViewController.numberOfPages = numberOfPages
            pageViewController.heading = details[index].title
            
            if details[index].tabletImage != "" && UIScreen.main.traitCollection.verticalSizeClass != .compact && UIScreen.main.traitCollection.horizontalSizeClass != .compact {
                pageViewController.imageFile = details[index].tabletImage
            } else {
                pageViewController.imageFile = details[index].image
            }
            
            if details[index].verbose != "" && UIScreen.main.traitCollection.verticalSizeClass != .compact && UIScreen.main.traitCollection.horizontalSizeClass != .compact {
                 pageViewController.content = details[index].verbose
            } else {
                pageViewController.content = details[index].compact
            }
            
            pageViewController.index = index
            
            return pageViewController
        }
    
        return nil
    }
    
    func forward(index: Int) {
        if let nextViewController = contentViewController(at: index + 1) {
            setViewControllers([nextViewController], direction: .forward, animated: true, completion: nil)
        }
    }
   
    override var prefersStatusBarHidden: Bool {
        get {
            return AppDelegate.applicationPrefersStatusBarHidden ?? true
        }
    }
    
    public static func show(from viewController: ScorecardViewController) {
        let storyboard = UIStoryboard(name: "WalkthroughPageViewController", bundle: nil)
        if let pageViewController = storyboard.instantiateViewController(withIdentifier: "WalkthroughPageViewController") as? WalkthroughPageViewController {
            pageViewController.modalPresentationStyle = .fullScreen
            viewController.present(pageViewController, animated: true, completion: nil)
        }
    }
}
