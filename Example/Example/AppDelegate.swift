//
//  AppDelegate.swift
//  Example
//
//  Created by David Ask on 2019-10-03.
//  Copyright © 2019 Bintrail AB. All rights reserved.
//

import Bintrail
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        do {
            try Bintrail.shared.configure(
                keyId: "NA9FGMOXOIEM96NO09QP",
                secret: "eEMBulGiWc7xdffh2kzb1TCfWSePRUl23sJloHzL"
            )
        } catch {
            print("Failed to configure Bintrail", error)
        }

        bt_log("App launched successfully", type: .info)

        print(sysctlString(named: "hw.model"))
        
        bt_log("This is a trace messag, perhaps not something you'd send always.", type: .trace)
        bt_log("Debug messages are interesting, but numerous", type: .debug)
        bt_log("Here's were we're getting some information", type: .info)
        bt_log("Oh no, but no biggie.", type: .warning)
        bt_log("Shoot, something went wrong!", type: .error)
        bt_log("It works on my machine!", type: .fatal)


        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

