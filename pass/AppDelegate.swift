//
//  AppDelegate.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import passKit
import SVProgressHUD
import SwiftyUserDefaults
import UIKit

// The window and quick actions live in SceneDelegate.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SVProgressHUD.setMinimumSize(CGSize(width: 150, height: 100))
        UNUserNotificationCenter.current().delegate = NotificationCenterDispatcher.shared
        return true
    }

    func applicationWillTerminate(_: UIApplication) {
        // Saves changes in the application's managed object context before the application terminates.
        PersistenceController.shared.save()
    }
}
