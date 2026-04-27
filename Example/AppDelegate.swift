//
//  AppDelegate.swift
//  Example
//
//  Created by Satheesh Kannan on 27/04/26.
//

import UIKit
import UserNotifications
import RudderStackAnalytics
import RudderIntegrationBraze
import BrazeKit
import BrazeUI

class AppDelegate: UIResponder, UIApplicationDelegate {

    private let brazePlugin = BrazeIntegration()
    private var pendingDeviceToken: Data?

    private var braze: Braze? {
        brazePlugin.getDestinationInstance() as? Braze
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAnalytics()
        setupPushNotifications(application)
        return true
    }

    private func setupAnalytics() {
        LoggerAnalytics.logLevel = .verbose

        let configuration = Configuration(
            writeKey: "<WRITE_KEY>",
            dataPlaneUrl: "<DATA_PLANE_URL>")

        let analytics = Analytics(configuration: configuration)
        analytics.add(plugin: brazePlugin)
        AnalyticsManager.shared.analytics = analytics

        brazePlugin.onDestinationReady { instance, result in
            if let braze = instance as? Braze {
                braze.inAppMessagePresenter = BrazeInAppMessageUI()
            }
        }
    }

    private func setupPushNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories(Braze.Notifications.categories)
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()
    }

    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if let braze {
            braze.notifications.register(deviceToken: deviceToken)
        } else {
            pendingDeviceToken = deviceToken
            brazePlugin.onDestinationReady { [weak self] instance, result in
                guard let self, case .success = result,
                      let token = self.pendingDeviceToken,
                      let braze = instance as? Braze else { return }
                braze.notifications.register(deviceToken: token)
                self.pendingDeviceToken = nil
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LoggerAnalytics.debug("Push registration failed: \(error)")
    }

    // MARK: - Background Push

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let braze, braze.notifications.handleBackgroundNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler) {
            return
        }
        completionHandler(.noData)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let braze, braze.notifications.handleUserNotification(response: response, withCompletionHandler: completionHandler) {
            return
        }
        completionHandler()
    }
}
