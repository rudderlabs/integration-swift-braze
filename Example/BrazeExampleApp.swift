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

        let traits: [String: Any] = [
            "email": "test@gmail.com",
            "firstName": "First Name",
            "lastName": "Last Name",
            "gender": "Male",
            "phone": "0123456789",
            "address": [
                "city": "Kolkata",
                "country": "India"
            ],
            "birthday": Date(),
            "key-1": "value-1",
            "key-2": 12341,
            "key-3": "1990-01-15T00:00:00.000Z",
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
            "currency": "INR",
            "key-1": "value-1",
            "key-2": 234,
        ]

        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with single product and revenue")
    }

    func orderCompletedWithMultipleProducts() {
        let properties: [String: Any] = [
            "products": [
                [
                    "product_id": "1002",
                    "quantity": 12,
                    "price": 100.22,
                    "product-key-1": "product-value-1",
                    "product-key-2": 123,
                ],
                [
                    "product_id": "1003",
                    "quantity": 5,
                    "price": 89.50,
                    "product-key-3": "product-value-3",
                    "product-key-4": 456,
                ]
            ],
            "currency": "INR",
            "key-1": "value-1",
            "key-2": 234,
            "key-3": "1990-01-15T00:00:00.000Z",
        ]

        analytics?.track(name: "Order Completed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Completed event with multiple products")
    }

    // MARK: - Custom Track Events

    func customTrackEventWithProperties() {
        let properties: [String: Any] = [
            "key_1": "value_1",
            "key_2": "value_2"
        ]

        analytics?.track(name: "Custom track event with properties", properties: properties)
        LoggerAnalytics.debug("✅ Tracked custom event with properties")
    }

    func customTrackEventWithoutProperties() {
        analytics?.track(name: "Custom track event without properties")
        LoggerAnalytics.debug("✅ Tracked custom event without properties")
    }

    // MARK: - Flush

    func flush() {
        analytics?.flush()
        LoggerAnalytics.debug("✅ Flushed analytics queue")
    }
}
