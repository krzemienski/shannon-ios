//
//  AppDelegate.swift
//  ClaudeCode
//
//  Handles push notification registration and app lifecycle events
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Setup push notifications
        setupPushNotifications()
        
        // Check if app was launched from notification
        if let launchOptions = launchOptions,
           let notification = launchOptions[.remoteNotification] as? [AnyHashable: Any] {
            Task {
                await NotificationManager.shared.processRemoteNotification(notification)
            }
        }
        
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.registerDeviceToken(deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.handleRegistrationError(error)
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Remote Notifications
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle silent push notifications
        Task {
            let result = await PushNotificationService.shared.handleSilentPush(userInfo)
            completionHandler(result)
        }
    }
    
    // MARK: - URL Handling
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle deep links
        if let deepLink = DeepLinkHandler.handleURL(url) {
            Task {
                await NotificationManager.shared.handleDeepLink(deepLink)
                NotificationActionHandler.shared.navigateToDeepLink(deepLink)
            }
            return true
        }
        
        return false
    }
    
    // MARK: - Background Tasks
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Handle background URL session events
        print("Background URL session: \(identifier)")
        completionHandler()
    }
    
    // MARK: - Lifecycle
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when app becomes active
        Task {
            await PushNotificationService.shared.clearBadge()
            await NotificationManager.shared.processQueuedNotifications()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Save any pending data
        print("App will resign active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App did enter background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("App will terminate")
    }
    
    // MARK: - Private Methods
    
    private func setupPushNotifications() {
        // Configure notification center
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        
        // Request provisional authorization on first launch
        if !UserDefaults.standard.bool(forKey: "hasRequestedNotificationPermission") {
            Task {
                do {
                    let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                        options: [.provisional, .badge, .sound]
                    )
                    
                    if granted {
                        await UIApplication.shared.registerForRemoteNotifications()
                    }
                    
                    UserDefaults.standard.set(true, forKey: "hasRequestedNotificationPermission")
                } catch {
                    print("Failed to request notification authorization: \(error)")
                }
            }
        } else {
            // Check current authorization status
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                
                if settings.authorizationStatus == .authorized ||
                   settings.authorizationStatus == .provisional {
                    await UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - Scene Delegate Support

extension AppDelegate {
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when the user discards a scene session
    }
}