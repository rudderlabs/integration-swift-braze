//
//  BrazeExampleApp.swift
//  BrazeExample
//
//  Created by Vishal Gupta on 21/11/25.
//

import SwiftUI

@main
struct BrazeExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
            externalIds: [ExternalId(type: "brazeExternalId", id: "463f2b09-ab10-457d-9835-b840f9fdf63f")]
        )

        let traits: [String: Any] = [
            "email": "test.swift@integration-test.com",
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

    // MARK: - Recommended Ecommerce Events

    /*
     * These RudderStack ecommerce track events map to Braze recommended `ecommerce.*`
     * events only when `useEcommerceRecommendedEvents` is enabled on the Braze destination
     * in the RudderStack dashboard. When the flag is off, they flow through the legacy /
     * custom-event path instead. Properties use the RS ecommerce spec field names that the
     * mappings consume; a few extra keys are included to demonstrate `metadata` routing.
     */

    func productViewed() {
        let properties: [String: Any] = [
            "product_id": "prod_001",
            "name": "Air Jordan 1",
            "variant": "red-42",
            "price": 129.99,
            "currency": "USD",
            "image_url": "https://example.com/img/aj1.png",
            "url": "https://example.com/products/aj1",
            "type": ["sneakers", "limited-edition"],
            "category": "footwear"
        ]

        analytics?.track(name: "Product Viewed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Product Viewed event")
    }

    func productAdded() {
        // For cart_updated, the top-level product fields are wrapped into a single product.
        let properties: [String: Any] = [
            "cart_id": "cart_123",
            "currency": "USD",
            "product_id": "prod_001",
            "name": "Air Jordan 1",
            "variant": "red-42",
            "quantity": 1,
            "price": 129.99,
            "image_url": "https://example.com/img/aj1.png",
            "url": "https://example.com/products/aj1"
        ]

        analytics?.track(name: "Product Added", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Product Added event (cart_updated, action: add)")
    }

    func productRemoved() {
        let properties: [String: Any] = [
            "cart_id": "cart_123",
            "currency": "USD",
            "product_id": "prod_001",
            "name": "Air Jordan 1",
            "variant": "red-42",
            "quantity": 1,
            "price": 129.99
        ]

        analytics?.track(name: "Product Removed", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Product Removed event (cart_updated, action: remove)")
    }

    func checkoutStarted() {
        let properties: [String: Any] = [
            "checkout_id": "chk_789",
            "cart_id": "cart_123",
            "total": 259.98,
            "subtotal_value": 239.98,
            "tax": 10.0,
            "shipping": 10.0,
            "currency": "USD",
            "products": [
                [
                    "product_id": "prod_001",
                    "name": "Air Jordan 1",
                    "variant": "red-42",
                    "quantity": 1,
                    "price": 129.99
                ],
                [
                    "product_id": "prod_002",
                    "name": "Yeezy 350",
                    "variant": "zebra-43",
                    "quantity": 1,
                    "price": 129.99
                ]
            ]
        ]

        analytics?.track(name: "Checkout Started", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Checkout Started event")
    }

    func orderRefunded() {
        let properties: [String: Any] = [
            "order_id": "order_456",
            "total": 129.99,
            "currency": "USD",
            "total_discounts": 10.0,
            "discounts": [
                [
                    "code": "SAVE10",
                    "amount": 10.0
                ]
            ],
            "products": [
                [
                    "product_id": "prod_001",
                    "name": "Air Jordan 1",
                    "variant": "red-42",
                    "quantity": 1,
                    "price": 129.99
                ]
            ]
        ]

        analytics?.track(name: "Order Refunded", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Refunded event")
    }

    func orderCancelled() {
        let properties: [String: Any] = [
            "order_id": "order_789",
            "total": 129.99,
            "currency": "USD",
            "cancel_reason": "Customer changed their mind",
            "tax": 5.0,
            "shipping": 5.0,
            "products": [
                [
                    "product_id": "prod_001",
                    "name": "Air Jordan 1",
                    "variant": "red-42",
                    "quantity": 1,
                    "price": 129.99
                ]
            ]
        ]

        analytics?.track(name: "Order Cancelled", properties: properties)
        LoggerAnalytics.debug("✅ Tracked Order Cancelled event")
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
