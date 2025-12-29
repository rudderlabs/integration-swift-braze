//
//  BrazeTestUtils.swift
//  integration-swift-braze
//
//  Created by Vishal Gupta on 21/11/25.
//

import Foundation
import BrazeKit
import RudderStackAnalytics
@testable import RudderIntegrationBraze

/**
 * Mock implementation of BrazeAdapter for testing
 */
class MockBrazeAdapter: BrazeAdapter {

    // MARK: - Tracking Variables
    var isInitialized = false
    var initSDKCalls: [(appIdentifierKey: String, endpoint: String, logLevel: LogLevel)] = []
    var changeUserCalls: [String] = []
    var addUserAliasCalls: [(alias: String, label: String)] = []
    var setUserAttributeCalls: [BrazeUserAttribute] = []
    var setTraitsCalls: [IdentifyTraits] = []
    var logCustomEventCalls: [(name: String, properties: [String: Any]?)] = []
    var logPurchaseCalls: [(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?)] = []
    var requestImmediateDataFlushCallCount = 0

    // MARK: - Configuration
    var shouldFailInitialization = false

    // MARK: - BrazeAdapter Implementation

    func initSDK(appIdentifierKey: String, endpoint: String, logLevel: LogLevel) -> Bool {
        initSDKCalls.append((appIdentifierKey: appIdentifierKey, endpoint: endpoint, logLevel: logLevel))
        if shouldFailInitialization {
            isInitialized = false
            return false
        }
        isInitialized = true
        return true
    }

    func changeUser(userId: String) {
        changeUserCalls.append(userId)
    }

    func addUserAlias(_ alias: String, label: String) {
        addUserAliasCalls.append((alias: alias, label: label))
    }

    func setUserAttribute(_ attribute: BrazeUserAttribute) {
        setUserAttributeCalls.append(attribute)
    }

    func setTraits(deDupedTraits: IdentifyTraits) {
        setTraitsCalls.append(deDupedTraits)
    }

    func logCustomEvent(name: String, properties: [String: Any]?) {
        logCustomEventCalls.append((name: name, properties: properties))
    }

    func logPurchase(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?) {
        logPurchaseCalls.append((productId: productId, currency: currency, price: price, quantity: quantity, properties: properties))
    }

    func requestImmediateDataFlush() {
        requestImmediateDataFlushCallCount += 1
    }

    func getDestinationInstance() -> Any? {
        return isInitialized ? "MockBrazeInstance" : nil
    }

    // MARK: - Helper Methods

    func reset() {
        isInitialized = false
        initSDKCalls.removeAll()
        changeUserCalls.removeAll()
        addUserAliasCalls.removeAll()
        setUserAttributeCalls.removeAll()
        setTraitsCalls.removeAll()
        logCustomEventCalls.removeAll()
        logPurchaseCalls.removeAll()
        requestImmediateDataFlushCallCount = 0
        shouldFailInitialization = false
    }
}

// MARK: - Test Data Providers

struct BrazeTestData {

    static var validConfig: [String: Any] {
        [
            "appKey": "test-api-key-123",
            "dataCenter": "US-01",
            "supportDedup": true,
            "connectionMode": "device"
        ]
    }

    static var hybridModeConfig: [String: Any] {
        [
            "appKey": "test-api-key-123",
            "dataCenter": "US-01",
            "supportDedup": false,
            "connectionMode": "hybrid"
        ]
    }

    static var configWithDedupDisabled: [String: Any] {
        [
            "appKey": "test-api-key-123",
            "dataCenter": "US-01",
            "supportDedup": false,
            "connectionMode": "device"
        ]
    }

    static var invalidConfig: [String: Any] {
        [
            "dataCenter": "US-01",
            "supportDedup": true
            // Missing appKey
        ]
    }

    static var invalidDataCenterConfig: [String: Any] {
        [
            "appKey": "test-api-key-123",
            "dataCenter": "INVALID-DC",
            "supportDedup": true
        ]
    }

    // MARK: - Platform-Specific App Identifier Key Test Configurations

    static var configWithIosApiKey: [String: Any] {
        [
            "appKey": "legacyAppKey",
            "iOSApiKey": "iosSpecificApiKey",
            "usePlatformSpecificApiKeys": true,
            "dataCenter": "US-03",
            "supportDedup": true,
            "connectionMode": "device"
        ]
    }

    static var configWithFlagDisabled: [String: Any] {
        [
            "appKey": "legacyAppKey",
            "iOSApiKey": "iosSpecificApiKey",
            "usePlatformSpecificApiKeys": false,
            "dataCenter": "US-03",
            "supportDedup": true,
            "connectionMode": "device"
        ]
    }

    static var configWithBlankIosApiKey: [String: Any] {
        [
            "appKey": "legacyAppKey",
            "iOSApiKey": " ",
            "usePlatformSpecificApiKeys": true,
            "dataCenter": "US-03",
            "supportDedup": true,
            "connectionMode": "device"
        ]
    }

    // MARK: - Identity Event Data

    static var basicUserTraits: [String: Any] {
        [
            "email": "test@example.com",
            "firstname": "John",
            "lastname": "Doe"
        ]
    }

    static var completeUserTraits: [String: Any] {
        [
            "email": "test@example.com",
            "firstname": "John",
            "lastname": "Doe",
            "phone": "+1234567890",
            "gender": "male",
            "birthday": Date(timeIntervalSince1970: 631152000), // 1990-01-01
            "address": [
                "city": "San Francisco",
                "country": "USA"
            ],
            "customString": "custom_value",
            "customBool": true,
            "customInt": 42,
            "customDouble": 3.14,
            "customDate": Date(),
            "customArray": ["item1", "item2"]
        ]
    }

    static var updatedUserTraits: [String: Any] {
        [
            "email": "updated@example.com",
            "firstname": "Jane",
            "lastname": "Smith",
            "phone": "+0987654321",
            "gender": "female",
            "customString": "updated_value"
        ]
    }

    // MARK: - Track Event Data

    static var customEventProperties: [String: Any] {
        [
            "category": "test",
            "value": 100,
            "isActive": true
        ]
    }

    static var installAttributedProperties: [String: Any] {
        [
            "campaign": [
                "source": "facebook",
                "name": "summer_campaign",
                "ad_group": "mobile_users",
                "ad_creative": "video_ad_1"
            ]
        ]
    }

    static var installAttributedPropertiesWithoutCampaign: [String: Any] {
        [
            "source": "organic",
            "medium": "direct"
        ]
    }

    static var orderCompletedProperties: [String: Any] {
        [
            "order_id": "order_123",
            "revenue": 199.99,
            "currency": "USD",
            "discount": 20.0,
            "products": [
                [
                    "product_id": "prod_001",
                    "name": "Product 1",
                    "price": 99.99,
                    "quantity": 2,
                    "category": "electronics"
                ],
                [
                    "product_id": "prod_002",
                    "name": "Product 2",
                    "price": 50.0,
                    "quantity": 1,
                    "category": "books"
                ]
            ]
        ]
    }

    static var orderCompletedPropertiesWithoutProducts: [String: Any] {
        [
            "order_id": "order_456",
            "revenue": 99.99,
            "currency": "EUR"
        ]
    }

    static var orderCompletedPropertiesWithMixedDataTypes: [String: Any] {
        [
            "order_id": "order_789",
            "currency": "GBP",
            "products": [
                [
                    "product_id": "prod_003",
                    "price": 25.50, // String price
                    "quantity": 3 // String quantity
                ]
            ]
        ]
    }
}

// MARK: - Event Creation Helpers

extension BrazeTestData {

    static func createIdentifyEvent(
        userId: String? = "test_user_123",
        traits: [String: Any]? = nil,
        externalIds: [[String: Any]]? = nil
    ) -> IdentifyEvent {
        var event = IdentifyEvent()
        event.userId = userId

        var context: [String: Any] = [:]
        if let traits = traits {
            context["traits"] = traits
        }
        if let externalIds = externalIds {
            context["externalId"] = externalIds
        }

        if !context.isEmpty {
            event.context = context.mapValues { AnyCodable($0) }
        }

        return event
    }

    static func createTrackEvent(
        name: String,
        properties: [String: Any]? = nil
    ) -> TrackEvent {
        return TrackEvent(event: name, properties: properties)
    }

    static func createExternalIds(brazeExternalId: String) -> [[String: Any]] {
        return [
            [
                "type": "brazeExternalId",
                "id": brazeExternalId
            ]
        ]
    }
}
