import Testing
import Foundation
import RudderStackAnalytics
import BrazeKit
@testable import RudderIntegrationBraze

@Suite(.serialized)
class BrazeIntegrationTests {

    // MARK: - Test Properties

    private var mockAdapter: MockBrazeAdapter!
    private var brazeIntegration: BrazeIntegration!
    private var mockAnalytics: Analytics!

    // MARK: - Setup and Teardown

    init() {
        // Setup phase: runs before each test
        LoggerAnalytics.info("BrazeIntegrationTests: Setting up test environment")

        // Initialize common test objects
        self.mockAdapter = MockBrazeAdapter()
        self.brazeIntegration = BrazeIntegration(brazeAdapter: mockAdapter)

        // Create mock analytics instance
        let config = Configuration(writeKey: "test-write-key", dataPlaneUrl: "https://test.rudderstack.com")
        self.mockAnalytics = Analytics(configuration: config)

        // Set analytics on integration (most tests need this)
        self.brazeIntegration.analytics = mockAnalytics

        LoggerAnalytics.info("BrazeIntegrationTests: Common test objects initialized")
    }

    deinit {
        // Teardown phase: runs after each test
        LoggerAnalytics.info("BrazeIntegrationTests: Tearing down test environment")

        // Clean up test objects
        self.mockAdapter = nil
        self.brazeIntegration = nil
        self.mockAnalytics = nil

        LoggerAnalytics.info("BrazeIntegrationTests: Test objects cleaned up")
    }

    // MARK: - Test Setup Helpers

    /// Helper to create integration with default config (device mode, dedup enabled)
    private func setupWithDefaultConfig() throws {
        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)
    }

    /// Helper to create integration with custom config
    private func setupWithConfig(_ config: [String: Any]) throws {
        try brazeIntegration.create(destinationConfig: config)
    }

    /// Helper to create a fresh integration instance (for tests that need isolation)
    private func createFreshIntegration(mockAdapter: MockBrazeAdapter? = nil) -> BrazeIntegration {
        let adapter = mockAdapter ?? MockBrazeAdapter()
        let integration = BrazeIntegration(brazeAdapter: adapter)
        integration.analytics = mockAnalytics
        return integration
    }

    // MARK: - Create/Setup Tests

    @Test("given successfully initialized integration, when getDestinationInstance is called, then returns instance")
    func testGetDestinationInstanceWhenInitialized() throws {
        try setupWithDefaultConfig()
        let instance = brazeIntegration.getDestinationInstance()

        #expect(instance != nil)
        #expect(instance as? String == "MockBrazeInstance")
    }

    @Test("given uninitialized integration, when getDestinationInstance is called, then returns nil")
    func testGetDestinationInstanceWhenNotInitialized() throws {
        let instance = brazeIntegration.getDestinationInstance()

        #expect(instance == nil)
    }

    // MARK: - Update Configuration Tests

    @Test("given initialized integration, when update is called, then configuration is updated")
    func testUpdateConfiguration() throws {
        try setupWithDefaultConfig()
        
        try brazeIntegration.update(destinationConfig: BrazeTestData.configWithDedupDisabled)

        // Should not reinitialize Braze but should update internal configuration
        #expect(mockAdapter.initSDKCalls.count == 1) // Only from create call
    }

    // MARK: - Platform-Specific API Key Tests

    @Test("given platform-specific key is enabled and iOSApiKey is present, when integration is initialized, then iOSApiKey should be used")
    func testPlatformSpecificKeyEnabledWithIosApiKey() throws {
        try setupWithConfig(BrazeTestData.configWithIosApiKey)

        #expect(mockAdapter.initSDKCalls.count == 1)
        #expect(mockAdapter.isInitialized == true)
        #expect(mockAdapter.initSDKCalls[0].apiKey == "iosSpecificApiKey")
        #expect(mockAdapter.initSDKCalls[0].endpoint == "sdk.iad-03.braze.com")
    }

    @Test("given platform-specific key flag is disabled, when integration is initialized, then legacy appKey should be used")
    func testPlatformSpecificKeyFlagDisabled() throws {
        try setupWithConfig(BrazeTestData.configWithFlagDisabled)

        #expect(mockAdapter.initSDKCalls.count == 1)
        #expect(mockAdapter.isInitialized == true)
        #expect(mockAdapter.initSDKCalls[0].apiKey == "legacyAppKey")
        #expect(mockAdapter.initSDKCalls[0].endpoint == "sdk.iad-03.braze.com")
    }

    @Test("given platform-specific key is enabled but iosApiKey is blank, when integration is initialized, then legacy appKey should be used as fallback")
    func testPlatformSpecificKeyEnabledButBlankIosApiKey() throws {
        try setupWithConfig(BrazeTestData.configWithBlankIosApiKey)

        #expect(mockAdapter.initSDKCalls.count == 1)
        #expect(mockAdapter.isInitialized == true)
        #expect(mockAdapter.initSDKCalls[0].apiKey == "legacyAppKey")
    }

    @Test("given platform-specific key is enabled but iosApiKey is missing, when integration is initialized, then legacy appKey should be used as fallback")
    func testPlatformSpecificKeyEnabledButMissingIosApiKey() throws {
        var configWithoutIosKey = BrazeTestData.configWithIosApiKey
        configWithoutIosKey.removeValue(forKey: "iOSApiKey")

        try setupWithConfig(configWithoutIosKey)

        #expect(mockAdapter.initSDKCalls.count == 1)
        #expect(mockAdapter.isInitialized == true)
        #expect(mockAdapter.initSDKCalls[0].apiKey == "legacyAppKey")
    }

    // MARK: - Identify Event Tests - Device Mode

    @Test("given device mode and basic user traits, when identify is called, then user attributes are set")
    func testIdentifyWithBasicUserTraits() throws {
        try setupWithDefaultConfig()
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        // Verify basic user attributes were set
        #expect(mockAdapter.setTraitsCalls.count == 1)
    }

    @Test("given device mode and complete user traits, when identify is called, then all user attributes are set")
    func testIdentifyWithCompleteUserTraits() throws {
        try setupWithDefaultConfig()
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.completeUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        // Verify traits were set
        #expect(mockAdapter.setTraitsCalls.count == 1)
    }

    @Test("given device mode and external ID, when identify is called, then changeUser uses external ID")
    func testIdentifyWithExternalId() throws {
        try setupWithDefaultConfig()
        let externalIds = BrazeTestData.createExternalIds(brazeExternalId: "braze_external_123")
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits,
            externalIds: externalIds
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "braze_external_123") // Should use external ID, not user ID
        // Verify traits were set
        #expect(mockAdapter.setTraitsCalls.count == 1)
    }

    @Test("given device mode and dedup enabled with same traits, when identify is called twice, then traits are not set on second call")
    func testIdentifyWithDedupEnabledSameTraits() throws {
        try setupWithDefaultConfig() // supportDedup: true
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        // First identify call
        brazeIntegration.identify(payload: identifyEvent)

        // Verify first call set correct attributes
        let firstCallTraitsCount = mockAdapter.setTraitsCalls.count
        #expect(firstCallTraitsCount == 1)

        // Reset counters to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.setTraitsCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with same traits
        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // User ID unchanged, no changeUser call
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No attributes set due to dedup
        #expect(mockAdapter.setTraitsCalls.count == 1) // setTraits called but with deduped (nil) traits
    }

    @Test("given device mode and dedup enabled with different traits, when identify is called twice, then only changed traits are set")
    func testIdentifyWithDedupEnabledDifferentTraits() throws {
        try setupWithDefaultConfig() // supportDedup: true
        let firstIdentifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )
        let secondIdentifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.updatedUserTraits
        )

        // First identify call
        brazeIntegration.identify(payload: firstIdentifyEvent)

        // Reset counters to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.setTraitsCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with different traits
        brazeIntegration.identify(payload: secondIdentifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // User ID unchanged
        // Verify changed attributes were updated
        #expect(mockAdapter.setTraitsCalls.count == 1)
    }

    @Test("given device mode and dedup disabled, when identify is called twice with same traits, then traits are set both times")
    func testIdentifyWithDedupDisabled() throws {
        try setupWithConfig(BrazeTestData.configWithDedupDisabled)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        // First identify call
        brazeIntegration.identify(payload: identifyEvent)
        let firstCallTraitsCount = mockAdapter.setTraitsCalls.count

        // Reset counters to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.setTraitsCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with same traits
        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1) // Dedup OFF: changeUser called again
        #expect(mockAdapter.setTraitsCalls.count == firstCallTraitsCount) // All traits set again
    }

    // MARK: - Identify Event Tests - Hybrid Mode


    @Test("given hybrid mode, when identify is called, then no Braze calls are made")
    func testIdentifyInHybridMode() throws {
        try setupWithConfig(BrazeTestData.hybridModeConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
        #expect(mockAdapter.setTraitsCalls.count == 0)
    }

    // MARK: - Track Event Tests - Device Mode

    @Test("given device mode and custom event, when track is called, then custom event is logged")
    func testTrackCustomEvent() throws {
        try setupWithDefaultConfig()

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Custom Event",
            properties: BrazeTestData.customEventProperties
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Custom Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties != nil)
    }

    @Test("given device mode and custom event without properties, when track is called, then event is logged with empty properties")
    func testTrackCustomEventWithoutProperties() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(name: "Simple Event")

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Simple Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties?.isEmpty == true)
    }

    @Test("given device mode and Install Attributed event with campaign, when track is called, then attribution data is set")
    func testTrackInstallAttributedEventWithCampaign() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Install Attributed",
            properties: BrazeTestData.installAttributedProperties
        )

        brazeIntegration.track(payload: trackEvent)

        let attributionDataSet = mockAdapter.setUserAttributeCalls.contains { attr in
            if case .attributionData = attr {
                return true
            }
            return false
        }
        #expect(attributionDataSet == true)
        #expect(mockAdapter.logCustomEventCalls.count == 0) // Should not log as custom event
    }

    @Test("given device mode and Install Attributed event without campaign, when track is called, then logs as custom event")
    func testTrackInstallAttributedEventWithoutCampaign() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Install Attributed",
            properties: BrazeTestData.installAttributedPropertiesWithoutCampaign
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Install Attributed")
    }

    @Test("given device mode and Order Completed event with products, when track is called, then purchase events are logged")
    func testTrackOrderCompletedEventWithProducts() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Order Completed",
            properties: BrazeTestData.orderCompletedProperties
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logPurchaseCalls.count == 2) // Two products in test data
        #expect(mockAdapter.logPurchaseCalls[0].productId == "prod_001")
        #expect(mockAdapter.logPurchaseCalls[0].currency == "USD")
        #expect(mockAdapter.logPurchaseCalls[0].price == 99.99)
        #expect(mockAdapter.logPurchaseCalls[0].quantity == 2)

        #expect(mockAdapter.logPurchaseCalls[1].productId == "prod_002")
        #expect(mockAdapter.logPurchaseCalls[1].currency == "USD")
        #expect(mockAdapter.logPurchaseCalls[1].price == 50.0)
        #expect(mockAdapter.logPurchaseCalls[1].quantity == 1)
    }

    @Test("given device mode and Order Completed event without products, when track is called, then no purchase events are logged")
    func testTrackOrderCompletedEventWithoutProducts() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Order Completed",
            properties: BrazeTestData.orderCompletedPropertiesWithoutProducts
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logPurchaseCalls.count == 0)
    }

    @Test("given device mode and Order Completed event with mixed data types, when track is called, then handles data type conversion")
    func testTrackOrderCompletedEventWithMixedDataTypes() throws {
        try setupWithDefaultConfig()
        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Order Completed",
            properties: BrazeTestData.orderCompletedPropertiesWithMixedDataTypes
        )
        
        brazeIntegration.track(payload: trackEvent)
        
        #expect(mockAdapter.logPurchaseCalls.count == 1)
        #expect(mockAdapter.logPurchaseCalls[0].productId == "prod_003")
        #expect(mockAdapter.logPurchaseCalls[0].currency == "GBP")
        #expect(mockAdapter.logPurchaseCalls[0].price == 25.50)
        #expect(mockAdapter.logPurchaseCalls[0].quantity == 3)
    }

    // MARK: - Track Event Tests - Hybrid Mode

    @Test("given hybrid mode, when track is called, then no Braze calls are made")
    func testTrackInHybridMode() throws {
        try setupWithConfig(BrazeTestData.hybridModeConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Custom Event",
            properties: BrazeTestData.customEventProperties
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 0)
        #expect(mockAdapter.logPurchaseCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
    }

    // MARK: - Flush Tests

    @Test("given initialized integration, when flush is called, then data flush is requested")
    func testFlush() throws {
        try setupWithDefaultConfig()

        brazeIntegration.flush()

        #expect(mockAdapter.requestImmediateDataFlushCallCount == 1)
    }

    // MARK: - Data Type Handling Tests

    @Test("given identify event with various data types for custom attributes, when identify is called, then all data types are handled correctly")
    func testIdentifyWithVariousDataTypes() throws {
        try setupWithDefaultConfig()

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.completeUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        // Verify traits were set (data types are handled in setTraits call)
        #expect(mockAdapter.setTraitsCalls.count == 1)

        // Verify the custom traits were passed correctly
        let traits = mockAdapter.setTraitsCalls[0]
        #expect(!traits.customTraits.isEmpty)
        #expect(traits.customTraits["customString"] as? String == "custom_value")
        #expect(traits.customTraits["customBool"] as? Bool == true)
        #expect(traits.customTraits["customInt"] as? Int == 42)
        #expect(traits.customTraits["customDouble"] as? Double == 3.14)
    }

    // MARK: - Gender Handling Tests

    @Test("given identify event with different gender formats, when identify is called, then gender is passed correctly in traits")
    func testIdentifyWithDifferentGenderFormats() throws {
        try setupWithDefaultConfig()

        // Test male gender
        let maleTraits = ["gender": "male"]
        let maleEvent = BrazeTestData.createIdentifyEvent(userId: "user1", traits: maleTraits)
        brazeIntegration.identify(payload: maleEvent)

        // Test female gender (short form)
        let femaleTraits = ["gender": "f"]
        let femaleEvent = BrazeTestData.createIdentifyEvent(userId: "user2", traits: femaleTraits)
        brazeIntegration.identify(payload: femaleEvent)

        // Should have 3 changeUser calls
        #expect(mockAdapter.changeUserCalls.count == 2)

        // Verify that all three setTraits calls were made with correct genders
        #expect(mockAdapter.setTraitsCalls.count == 2)
        #expect(mockAdapter.setTraitsCalls[0].context.traits.gender == "male")
        #expect(mockAdapter.setTraitsCalls[1].context.traits.gender == "f")
    }

    // MARK: - Edge Cases and Error Handling Tests

    @Test("given identify event with nil traits, when identify is called, then handles gracefully")
    func testIdentifyWithNilTraits() throws {
        try setupWithDefaultConfig()

        let identifyEvent = BrazeTestData.createIdentifyEvent(userId: "test_user_123", traits: nil)

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No traits to process
        #expect(mockAdapter.setTraitsCalls.count == 1) // setTraits called even with nil traits
    }

    @Test("given track event with nil properties, when track is called, then handles gracefully")
    func testTrackWithNilProperties() throws {
        try setupWithDefaultConfig()

        let trackEvent = BrazeTestData.createTrackEvent(name: "Simple Event", properties: nil)

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Simple Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties?.isEmpty == true)
    }

    // MARK: - Configuration Edge Cases Tests

    @Test("given all supported data center configurations, when create is called, then proper endpoints are set")
    func testAllSupportedDataCenters() throws {
        let dataCenters = [
            "US-01", "US-02", "US-03", "US-04", "US-05", "US-06", "US-07", "US-08",
            "EU-01", "EU-02", "AU-01"
        ]

        for dataCenter in dataCenters {
            // Create fresh adapter for each iteration
            let freshAdapter = MockBrazeAdapter()
            let freshIntegration = createFreshIntegration(mockAdapter: freshAdapter)

            let config: [String: Any] = [
                "appKey": "test-api-key",
                "dataCenter": dataCenter,
                "supportDedup": false,
                "connectionMode": "device"
            ]

            // Should not throw for valid data centers
            try freshIntegration.create(destinationConfig: config)
            #expect(freshAdapter.isInitialized == true)

            freshAdapter.reset()
        }
    }

    @Test("given integration without analytics instance, when create is called, then initializes without user alias")
    func testCreateWithoutAnalyticsInstance() throws {
        // Create a fresh integration without analytics
        let freshAdapter = MockBrazeAdapter()
        let freshIntegration = BrazeIntegration(brazeAdapter: freshAdapter)
        // NOT setting analytics instance

        try freshIntegration.create(destinationConfig: BrazeTestData.validConfig)

        #expect(freshAdapter.isInitialized == true)
        #expect(freshAdapter.initSDKCalls.count == 1)
        #expect(freshAdapter.addUserAliasCalls.count == 0) // No alias set without analytics
    }
}

