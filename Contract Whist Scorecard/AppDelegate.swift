//
//  AppDelegate.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    // Status bar switch
    public static var applicationPrefersStatusBarHidden: Bool?
    
    // Contract Whist state
    public var notificationSimulator: NotificationSimulator!
  
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
                        
        registerDefaults()
        
        // Cache main context for core data
        CoreData.context = self.persistentContainer.viewContext

        // Load scorecard and set color theme
        let _ = Scorecard.shared
        Themes.selectTheme(Scorecard.settings.colorTheme)

        // Check if launched from notification
        if let options = launchOptions {
            let remoteNotification = options[.remoteNotification] as? [AnyHashable : Any]
            if let userInfo = remoteNotification {
                Utility.mainThread {
                    self.processNotification(notification: CKNotification(fromRemoteNotificationDictionary: userInfo)!, confirm: false)
                }
            }
        }
        
        // Setup initial view controller
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.overrideUserInterfaceStyle = Scorecard.settings.appearance.userInterfaceStyle

        let storyboard = UIStoryboard(name: "ClientViewController", bundle: nil)
        let initialViewController = storyboard.instantiateViewController(withIdentifier: "ClientViewController") as! ClientViewController
        initialViewController.rootViewController = initialViewController
        
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
       
        return true
    }

    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "bonus2":                               true,
            "cards":                                [13, 1],
            "bounceNumberCards":                    false,
            "syncEnabled":                          false,
            "saveHistory":                          true,
            "saveLocation":                         false,
            "receiveNotifications":                 false,
            "allowBroadcast":                       true,
            "version":                              0.0,
            "build":                                0,
            "blockAccess":                          false,
            "blockSync":                            true,
            "message":                              "",
            "database":                             "",
            "rabbitMQUri":                          "",
            "alertVibrate":                         true,
            "thisPlayerUUID":                       "",
            "faceTimeAddress":                      "",
            "onlineGamesEnabled":                   false,
            "rawColorTheme":                        ThemeName.standard.rawValue,
            "rawAppearance":                        ThemeAppearance.device.rawValue,
            "tempOnlinePlayerUUID":                 false,
            "trumpSequence":                        ["♣︎", "♦︎", "♥︎" ,"♠︎", "NT"],
            "prefersStatusBarHidden":               true,
            "termsDevice":                          "",
            "termsUser":                            "",
            "confettiWin":                          false,
            "rawOnlineGamesEnabledSettingState":    SettingState.availableNotify.rawValue,
            "rawConfettiWinSettingState":           SettingState.notAvailable.rawValue
        ])
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        self.processNotification(notification: CKNotification(fromRemoteNotificationDictionary: userInfo)!, confirm: true)
    }
    
    private func processNotification(notification: CKNotification, confirm: Bool) {
        let args = notification.alertLocalizationArgs
        let message = String(format: notification.alertLocalizationKey!, arguments: args!)
        let viewController = Utility.getActiveViewController()
        let category = notification.category
        if category == "onlineGame" {
            Notifications.processOnlineGameNotification(message: message, args: args!, category: category!, confirm: confirm)
        } else {
            viewController?.alertMessage(message , title: "Notification")
        }
    }
    
    // MARK: - - Core Data stack -
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "Contract_Whist_Scorecard")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - - Core Data Saving support -

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

