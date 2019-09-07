//
//  AppDelegate.swift
//  inbox-ui-tests-app
//
//  Created by Tapash Majumder on 8/27/19.
//  Copyright © 2019 Iterable. All rights reserved.
//

import UIKit
import UserNotifications

@testable import IterableSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var sharedInstance: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var window: UIWindow?
    var mockInAppFetcher: MockInAppFetcher!
    var mockNetworkSession: MockNetworkSession!
    var networkTableViewController: NetworkTableViewController {
        let tabBarController = window!.rootViewController! as! UITabBarController
        let nav = tabBarController.viewControllers![tabBarController.viewControllers!.count - 1] as! UINavigationController
        return nav.viewControllers[0] as! NetworkTableViewController
    }
    
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        mockInAppFetcher = MockInAppFetcher(messages: InAppTestHelper.inAppMessages(fromPayload: createPayload()))
        mockNetworkSession = MockNetworkSession(statusCode: 200)
        mockNetworkSession.callback = { _, _, _ in
            self.logRequest()
        }
        
        let config = IterableConfig()
        config.customActionDelegate = self
        config.urlDelegate = self
        TestHelper.getTestUserDefaults().set("user1@example.com", forKey: .ITBL_USER_DEFAULTS_EMAIL_KEY)
        IterableAPI.initializeForTesting(config: config,
                                         networkSession: mockNetworkSession,
                                         inAppFetcher: mockInAppFetcher,
                                         urlOpener: AppUrlOpener())
        
        _ = mockInAppFetcher.fetch()
        
        return true
    }
    
    func applicationWillResignActive(_: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func addInboxMessage() {
        if let max = indices.max() {
            indices = indices + [max + 1]
        } else {
            indices = [1]
        }
        mockInAppFetcher.mockInAppPayloadFromServer(createPayload())
    }
    
    private var indices = [1, 2, 3]
    
    private func createPayload() -> [AnyHashable: Any] {
        return TestInAppPayloadGenerator.createPayloadWithUrl(indices: indices, saveToInbox: true)
    }
    
    private func logRequest() {
        let request = mockNetworkSession.request!
        let serializableRequest = request.createSerializableRequest()
        networkTableViewController.requests.append(serializableRequest)
        networkTableViewController.tableView.reloadData()
    }
}

extension AppDelegate: IterableCustomActionDelegate {
    func handle(iterableCustomAction action: IterableAction, inContext _: IterableActionContext) -> Bool {
        ITBInfo("handleCustomAction: \(action)")
        NotificationCenter.default.post(name: .handleIterableCustomAction, object: nil, userInfo: ["name": action.type])
        return true
    }
}

extension AppDelegate: IterableURLDelegate {
    func handle(iterableURL url: URL, inContext _: IterableActionContext) -> Bool {
        ITBInfo("handleUrl: \(url)")
        if url.absoluteString == "https://www.google.com" {
            // I am not going to handle this, do default
            return false
        } else {
            // I am handling this
            NotificationCenter.default.post(name: .handleIterableUrl, object: nil, userInfo: ["url": url.absoluteString])
            return true
        }
    }
}

extension Notification.Name {
    static let handleIterableUrl = Notification.Name("handleIterableUrl")
    static let handleIterableCustomAction = Notification.Name("handleIterableCustomAction")
}
