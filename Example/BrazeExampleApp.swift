//
//  BrazeExampleApp.swift
//  BrazeExample
//
//  Created by Vishal Gupta on 21/11/25.
//

import SwiftUI
import Combine
import RudderStackAnalytics
import RudderIntegrationBraze

@main
struct BrazeExampleApp: App {

    init() {
        setupAnalytics()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupAnalytics() {
        LoggerAnalytics.logLevel = .verbose

        // Configuration for RudderStack Analytics
        let configuration = Configuration(writeKey: "WRITE_KEY", dataPlaneUrl: "DATA_PLANE_URL")

        // Initialize Analytics
        let analytics = Analytics(configuration: configuration)

        // Add Braze Integration
        let brazeIntegration = BrazeIntegration()
        analytics.add(plugin: brazeIntegration)

        // Store analytics instance globally for access in ContentView
        AnalyticsManager.shared.analytics = analytics
    }
}

// Singleton to manage analytics instance
class AnalyticsManager {
    static let shared = AnalyticsManager()
    var analytics: Analytics?

    private init() {}
}

extension AnalyticsManager {

    // MARK: - User Identity

    func identifyUser() {
        let options = RudderOption(
            externalIds: [ExternalId(type: "brazeExternalId", id: "2d31d085-4d93-4126-b2b3-94e651810673")]
        )
        
        let birthday = Date()
        let traits: [String: Any] = [
            "birthday": birthday,
            "address": [
                "city": "Kolkata",
                "country": "India"
            ],
            "firstname": "First Name",
            "lastname": "Last Name",
            "gender": "Male",
            "phone": "0123456789",
            "email": "test@gmail.com",
            "key-1": "value-1",
            "key-2": 1234
        ]

        analytics?.identify(userId: "userid ios 1", traits: traits, options: options)
        LoggerAnalytics.debug("✅ Identified user with traits and external ID")
    }

    // MARK: - Install Attribution Events

    func installAttributedWithoutCampaign() {
        analytics?.track(name: "Install Attributed")
        LoggerAnalytics.debug("✅ Tracked Install Attributed event (no campaign)")
    }

    func installAttributedWithCampaign() {
        let properties: [String: Any] = [
            "campaign": [
                "source": "Source value",
                "name": "Name value",
                "ad_group": "ad_group value",
                "ad_creative": "ad_creative value"
            ]
        ]
        
        analytics?.track(name: "Install Attributed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Install Attributed event with campaign")
    }

    // MARK: - Order Completed Events

    func orderCompletedWithoutProducts() {
        analytics?.track(name: "Order Completed")
        LoggerAnalytics.debug("✅ Tracked Order Completed event (no products)")
    }

    func orderCompletedWithEmptyProducts() {
        let properties: [String: Any] = [
            "products": []
        ]
        
        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with empty products array")
    }

    func orderCompletedWithSingleProduct() {
        let properties: [String: Any] = [
            "products": [[
                "product_id": "10011",
                "quantity": 11,
                "price": 100.11,
                "Product-Key-1": "Product-Value-1"
            ]],
            "revenue": 123,
            "currency": "INR",
            "Key-1": "Value-1"
        ]
        
        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with single product and revenue")
    }

    func orderCompletedWithSingleProductSimple() {
        let properties: [String: Any] = [
            "products": [[
                "product_id": "1002",
                "quantity": 12,
                "price": 100.22
            ]],
            "currency": "INR"
        ]
        
        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with single product (simple)")
    }

    func orderCompletedWithMultipleProducts() {
        let properties: [String: Any] = [
            "products": [
                [
                    "product_id": "1002",
                    "quantity": 12,
                    "price": 100.22
                ],
                [
                    "product_id": "1003",
                    "quantity": 5,
                    "price": 89.50
                ]
            ],
            "currency": "INR"
        ]
        
        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with multiple products")
    }

    // MARK: - Custom Track Events

    func ecommTrackEvents() {
        let properties: [String: Any] = [
            "products": [[
                "product_id": "1002",
                "quantity": 12,
                "price": 100.22
            ]],
            "currency": "INR"
        ]
        
        analytics?.track(name: "Ecomm track events", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Ecomm track events")
    }

    func customTrackEventWithProperties() {
        let properties: [String: Any] = [
            "key_1": "value_1",
            "key_2": "value_2"
        ]
        
        analytics?.track(name: "New Track event", properties: properties)
        LoggerAnalytics.debug("✅ Tracked custom event with properties")
    }

    func customTrackEventWithoutProperties() {
        analytics?.track(name: "New Track event")
        LoggerAnalytics.debug("✅ Tracked custom event without properties")
    }
}
