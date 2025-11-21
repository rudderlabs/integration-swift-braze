import Testing
import Foundation
import RudderStackAnalytics
import BrazeKit
@testable import RudderIntegrationBraze

@Suite(.serialized)
struct BrazeIntegrationTests {

    // MARK: - Test Setup Helpers

    private func createBrazeIntegration(
        mockAdapter: MockBrazeAdapter = MockBrazeAdapter()
    ) -> BrazeIntegration {
        let integration = BrazeIntegration(brazeAdapter: mockAdapter)
        return integration
    }

    private func createMockAnalytics() -> Analytics {
        let config = Configuration(writeKey: "test-write-key", dataPlaneUrl: "https://test.rudderstack.com")
        let analytics = Analytics(configuration: config)
        return analytics
    }

    // MARK: - Initialization Tests

    @Test("Given BrazeIntegration, when initialized with default constructor, then creates proper integration")
    func testBrazeIntegrationDefaultInitialization() {
        let brazeIntegration = BrazeIntegration()

        #expect(brazeIntegration.key == "Braze")
        #expect(brazeIntegration.pluginType == .terminal)
        #expect(brazeIntegration.analytics == nil)
    }

    // MARK: - Create/Setup Tests

    @Test("Given configuration with missing API key, when create is called, then throws invalidAPIToken error")
    func testCreateWithMissingAPIKey() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        #expect(throws: BrazeIntegrationError.invalidAPIToken) {
            try brazeIntegration.create(destinationConfig: BrazeTestData.invalidConfig)
        }

        #expect(mockAdapter.initializeCallCount == 0)
    }

    @Test("Given configuration with invalid data center, when create is called, then throws invalidDataCenter error")
    func testCreateWithInvalidDataCenter() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        #expect(throws: BrazeIntegrationError.invalidDataCenter) {
            try brazeIntegration.create(destinationConfig: BrazeTestData.invalidDataCenterConfig)
        }

        #expect(mockAdapter.initializeCallCount == 0)
    }

    @Test("Given adapter initialization fails, when create is called, then throws initializationFailed error")
    func testCreateWithAdapterInitializationFailure() {
        let mockAdapter = MockBrazeAdapter()
        mockAdapter.shouldFailInitialization = true
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        #expect(throws: BrazeIntegrationError.initializationFailed) {
            try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)
        }

        #expect(mockAdapter.initializeCallCount == 1)
        #expect(mockAdapter.isInitialized == false)
    }

    @Test("Given successfully initialized integration, when getDestinationInstance is called, then returns instance")
    func testGetDestinationInstanceWhenInitialized() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)
        let instance = brazeIntegration.getDestinationInstance()

        #expect(instance != nil)
        #expect(instance as? String == "MockBrazeInstance")
    }

    @Test("Given uninitialized integration, when getDestinationInstance is called, then returns nil")
    func testGetDestinationInstanceWhenNotInitialized() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        let instance = brazeIntegration.getDestinationInstance()

        #expect(instance == nil)
    }

    // MARK: - Update Configuration Tests

    @Test("Given initialized integration, when update is called, then configuration is updated")
    func testUpdateConfiguration() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        try brazeIntegration.update(destinationConfig: BrazeTestData.configWithDedupDisabled)

        // Should not reinitialize Braze but should update internal configuration
        #expect(mockAdapter.initializeCallCount == 1) // Only from create call
    }

    // MARK: - Identify Event Tests - Device Mode

    @Test("Given device mode and basic user traits, when identify is called, then user attributes are set")
    func testIdentifyWithBasicUserTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        
        verifyBasicUserAttributes(mockAdapter)
    }

    @Test("Given device mode and complete user traits, when identify is called, then all user attributes are set")
    func testIdentifyWithCompleteUserTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.completeUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")

        // Verify standard attributes with actual values from BrazeTestData.completeUserTraits
        verifyEmailAttribute(mockAdapter, expectedValue: "test@example.com")
        verifyFirstNameAttribute(mockAdapter, expectedValue: "John")
        verifyLastNameAttribute(mockAdapter, expectedValue: "Doe")
        verifyPhoneAttribute(mockAdapter, expectedValue: "+1234567890")
        verifyGenderAttribute(mockAdapter, expectedValue: Braze.User.Gender.male)
        verifyHomeCityAttribute(mockAdapter, expectedValue: "San Francisco")
        verifyCountryAttribute(mockAdapter, expectedValue: "USA")
        
        // Verify custom attributes with actual values
        verifyCustomAttribute(mockAdapter, key: "customString", expectedValue: "custom_value")
        verifyCustomAttribute(mockAdapter, key: "customBool", expectedValue: true)
        verifyCustomAttribute(mockAdapter, key: "customInt", expectedValue: 42)
        verifyCustomAttribute(mockAdapter, key: "customDouble", expectedValue: 3.14)
    }

    @Test("Given device mode and external ID, when identify is called, then changeUser uses external ID")
    func testIdentifyWithExternalId() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let externalIds = BrazeTestData.createExternalIds(brazeExternalId: "braze_external_123")
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits,
            externalIds: externalIds
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "braze_external_123") // Should use external ID, not user ID
        
        verifyBasicUserAttributes(mockAdapter)
    }

    @Test("Given device mode and dedup enabled with same traits, when identify is called twice, then traits are not set on second call")
    func testIdentifyWithDedupEnabledSameTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        // First identify call
        brazeIntegration.identify(payload: identifyEvent)
        
        // Verify first call set correct attributes
        verifyBasicUserAttributes(mockAdapter)
        let firstCallAttributeCount = mockAdapter.setUserAttributeCalls.count

        // Reset counters to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.setCustomAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with same traits
        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // User ID unchanged, no changeUser call
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No attributes set due to dedup
        #expect(mockAdapter.setCustomAttributeCalls.count == 0) // No custom attributes set due to dedup

        #expect(firstCallAttributeCount > 0) // Verify first call worked
    }

    @Test("Given device mode and dedup enabled with different traits, when identify is called twice, then only changed traits are set")
    func testIdentifyWithDedupEnabledDifferentTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

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
        mockAdapter.setCustomAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with different traits
        brazeIntegration.identify(payload: secondIdentifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // User ID unchanged
        
        // Verify changed attributes were updated with actual values from BrazeTestData.updatedUserTraits
        verifyEmailAttribute(mockAdapter, expectedValue: "updated@example.com")
        verifyFirstNameAttribute(mockAdapter, expectedValue: "Jane")
        verifyLastNameAttribute(mockAdapter, expectedValue: "Smith")
        verifyPhoneAttribute(mockAdapter, expectedValue: "+0987654321")
        verifyGenderAttribute(mockAdapter, expectedValue: Braze.User.Gender.female)
        
        // Verify custom attribute changes
        verifyCustomAttribute(mockAdapter, key: "customString", expectedValue: "updated_value")
    }

    @Test("Given device mode and dedup disabled, when identify is called twice with same traits, then traits are set both times")
    func testIdentifyWithDedupDisabled() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.configWithDedupDisabled)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        // First identify call
        brazeIntegration.identify(payload: identifyEvent)
        let firstCallAttributeCount = mockAdapter.setUserAttributeCalls.count

        // Reset counters to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.setCustomAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        // Second identify call with same traits
        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // User ID unchanged
        #expect(mockAdapter.setUserAttributeCalls.count == firstCallAttributeCount) // All attributes set again
        
        // Verify attributes are set correctly on second call
        verifyBasicUserAttributes(mockAdapter)
    }

    // MARK: - Identify Event Tests - Cloud/Hybrid Mode

    @Test("Given cloud mode, when identify is called, then no Braze calls are made")
    func testIdentifyInCloudMode() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.cloudModeConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
        #expect(mockAdapter.setCustomAttributeCalls.count == 0)
    }

    @Test("Given hybrid mode, when identify is called, then no Braze calls are made")
    func testIdentifyInHybridMode() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.hybridModeConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.basicUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
        #expect(mockAdapter.setCustomAttributeCalls.count == 0)
    }

    // MARK: - Track Event Tests - Device Mode

    @Test("Given device mode and custom event, when track is called, then custom event is logged")
    func testTrackCustomEvent() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Custom Event",
            properties: BrazeTestData.customEventProperties
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Custom Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties != nil)
    }

    @Test("Given device mode and custom event without properties, when track is called, then event is logged with empty properties")
    func testTrackCustomEventWithoutProperties() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(name: "Simple Event")

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Simple Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties?.isEmpty == true)
    }

    @Test("Given device mode and Install Attributed event with campaign, when track is called, then attribution data is set")
    func testTrackInstallAttributedEventWithCampaign() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Install Attributed",
            properties: BrazeTestData.installAttributedProperties
        )

        brazeIntegration.track(payload: trackEvent)

        verifyAttributionDataAttribute(mockAdapter) // Verify attribution data was set
        #expect(mockAdapter.logCustomEventCalls.count == 0) // Should not log as custom event
    }

    @Test("Given device mode and Install Attributed event without campaign, when track is called, then logs as custom event")
    func testTrackInstallAttributedEventWithoutCampaign() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Install Attributed",
            properties: BrazeTestData.installAttributedPropertiesWithoutCampaign
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Install Attributed")
    }

    @Test("Given device mode and Order Completed event with products, when track is called, then purchase events are logged")
    func testTrackOrderCompletedEventWithProducts() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

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

    @Test("Given device mode and Order Completed event without products, when track is called, then no purchase events are logged")
    func testTrackOrderCompletedEventWithoutProducts() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Order Completed",
            properties: BrazeTestData.orderCompletedPropertiesWithoutProducts
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logPurchaseCalls.count == 0)
    }

    @Test("Given device mode and Order Completed event with mixed data types, when track is called, then handles data type conversion")
    func testTrackOrderCompletedEventWithMixedDataTypes() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

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

    // MARK: - Track Event Tests - Cloud/Hybrid Mode

    @Test("Given cloud mode, when track is called, then no Braze calls are made")
    func testTrackInCloudMode() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.cloudModeConfig)

        let trackEvent = BrazeTestData.createTrackEvent(
            name: "Custom Event",
            properties: BrazeTestData.customEventProperties
        )

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 0)
        #expect(mockAdapter.logPurchaseCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
    }

    @Test("Given hybrid mode, when track is called, then no Braze calls are made")
    func testTrackInHybridMode() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.hybridModeConfig)

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

    @Test("Given initialized integration, when flush is called, then data flush is requested")
    func testFlush() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        brazeIntegration.flush()

        #expect(mockAdapter.requestImmediateDataFlushCallCount == 1)
    }

    // MARK: - Data Type Handling Tests

    @Test("Given identify event with various data types for custom attributes, when identify is called, then all data types are handled correctly")
    func testIdentifyWithVariousDataTypes() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "test_user_123",
            traits: BrazeTestData.completeUserTraits
        )

        brazeIntegration.identify(payload: identifyEvent)

        let customAttributeCalls = mockAdapter.setCustomAttributeCalls

        // Verify different data types are handled
        let stringAttribute = customAttributeCalls.first { $0.key == "customString" }
        #expect(stringAttribute?.value as? String == "custom_value")

        let boolAttribute = customAttributeCalls.first { $0.key == "customBool" }
        #expect(boolAttribute?.value as? Bool == true)

        let intAttribute = customAttributeCalls.first { $0.key == "customInt" }
        #expect(intAttribute?.value as? Int == 42)

        let doubleAttribute = customAttributeCalls.first { $0.key == "customDouble" }
        #expect(doubleAttribute?.value as? Double == 3.14)

        let dateAttribute = customAttributeCalls.first { $0.key == "customDate" }
        #expect(dateAttribute?.value is Date)

        let arrayAttribute = customAttributeCalls.first { $0.key == "customArray" }
        #expect(arrayAttribute?.value is String) // Array should be converted to JSON string
    }

    // MARK: - Gender Handling Tests

    @Test("Given identify event with different gender formats, when identify is called, then gender is mapped correctly")
    func testIdentifyWithDifferentGenderFormats() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        // Test male variations
        let maleTraits = ["gender": "male"]
        let maleEvent = BrazeTestData.createIdentifyEvent(userId: "user1", traits: maleTraits)
        brazeIntegration.identify(payload: maleEvent)

        let femaleTraits = ["gender": "f"]
        let femaleEvent = BrazeTestData.createIdentifyEvent(userId: "user2", traits: femaleTraits)
        brazeIntegration.identify(payload: femaleEvent)

        let invalidTraits = ["gender": "other"]
        let invalidEvent = BrazeTestData.createIdentifyEvent(userId: "user3", traits: invalidTraits)
        brazeIntegration.identify(payload: invalidEvent)

        // Should have 3 changeUser calls and appropriate gender attribute calls
        #expect(mockAdapter.changeUserCalls.count == 3)

        // Verify that valid genders generated attribute calls (invalid gender won't)
        let genderAttributeCalls = mockAdapter.setUserAttributeCalls.filter { attribute in
            if case .gender = attribute { return true }
            return false
        }
        #expect(genderAttributeCalls.count == 2) // Only male and female should be processed
    }

    // MARK: - Edge Cases and Error Handling Tests

    @Test("Given identify event with nil traits, when identify is called, then handles gracefully")
    func testIdentifyWithNilTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(userId: "test_user_123", traits: nil)

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No traits to process
        #expect(mockAdapter.setCustomAttributeCalls.count == 0)
    }

    @Test("Given identify event with empty traits, when identify is called, then handles gracefully")
    func testIdentifyWithEmptyTraits() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let identifyEvent = BrazeTestData.createIdentifyEvent(userId: "test_user_123", traits: [:])

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "test_user_123")
        #expect(mockAdapter.setUserAttributeCalls.count == 0)
        #expect(mockAdapter.setCustomAttributeCalls.count == 0)
    }

    @Test("Given track event with nil properties, when track is called, then handles gracefully")
    func testTrackWithNilProperties() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let trackEvent = BrazeTestData.createTrackEvent(name: "Simple Event", properties: nil)

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logCustomEventCalls.count == 1)
        #expect(mockAdapter.logCustomEventCalls[0].name == "Simple Event")
        #expect(mockAdapter.logCustomEventCalls[0].properties?.isEmpty == true)
    }

    // MARK: - Integration Flow Tests

    @Test("Given complete user journey, when multiple events are processed, then all events are handled correctly")
    func testCompleteUserJourney() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        // Step 1: User identifies
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "journey_user_123",
            traits: BrazeTestData.basicUserTraits
        )
        brazeIntegration.identify(payload: identifyEvent)

        // Step 2: User performs custom action
        let customEvent = BrazeTestData.createTrackEvent(
            name: "Feature Used",
            properties: ["feature": "analytics_dashboard"]
        )
        brazeIntegration.track(payload: customEvent)

        // Step 3: User makes purchase
        let purchaseEvent = BrazeTestData.createTrackEvent(
            name: "Order Completed",
            properties: BrazeTestData.orderCompletedProperties
        )
        brazeIntegration.track(payload: purchaseEvent)

        // Step 4: Flush data
        brazeIntegration.flush()

        // Verify all events were processed
        #expect(mockAdapter.changeUserCalls.count == 1)
        verifyBasicUserAttributes(mockAdapter) // Verify actual attribute values from identify
        #expect(mockAdapter.logCustomEventCalls.count == 1) // Custom event
        #expect(mockAdapter.logPurchaseCalls.count == 2) // Two products from order
        #expect(mockAdapter.requestImmediateDataFlushCallCount == 1)
    }

    // MARK: - Configuration Edge Cases Tests

    @Test("Given all supported data center configurations, when create is called, then proper endpoints are set")
    func testAllSupportedDataCenters() throws {
        let dataCenters = [
            "US-01", "US-02", "US-03", "US-04", "US-05", "US-06", "US-07", "US-08",
            "EU-01", "EU-02", "AU-01"
        ]

        for dataCenter in dataCenters {
            let mockAdapter = MockBrazeAdapter()
            let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
            brazeIntegration.analytics = createMockAnalytics()

            let config: [String: Any] = [
                "appKey": "test-api-key",
                "dataCenter": dataCenter,
                "supportDedup": false,
                "connectionMode": "device"
            ]

            // Should not throw for valid data centers
            try brazeIntegration.create(destinationConfig: config)
            #expect(mockAdapter.isInitialized == true)

            mockAdapter.reset()
        }
    }

    @Test("Given integration without analytics instance, when create is called, then initializes without user alias")
    func testCreateWithoutAnalyticsInstance() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        // Not setting analytics instance

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        #expect(mockAdapter.isInitialized == true)
        #expect(mockAdapter.initializeCallCount == 1)
        #expect(mockAdapter.addUserAliasCalls.count == 0) // No alias set without analytics
        #expect(mockAdapter.setLogLevelCalls.count == 1)
    }

    // MARK: - Address Comparison Tests

    @Test("Given identify event with address changes, when identify is called with dedup enabled, then only changed address fields are updated")
    func testIdentifyWithAddressChanges() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

        let initialTraits: [String: Any] = [
            "address": [
                "city": "San Francisco",
                "country": "USA"
            ]
        ]

        let updatedTraits: [String: Any] = [
            "address": [
                "city": "New York", // Changed
                "country": "USA"     // Same
            ]
        ]

        let firstEvent = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: initialTraits)
        let secondEvent = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: updatedTraits)

        brazeIntegration.identify(payload: firstEvent)

        // Reset to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        brazeIntegration.identify(payload: secondEvent)

        #expect(mockAdapter.changeUserCalls.count == 0) // Same user ID
        verifyHomeCityAttribute(mockAdapter, expectedValue: "New York") // Verify city was updated
        verifyCountryAttribute(mockAdapter, expectedValue: "USA") // Country should also be set
    }

    @Test("Given identify event with same address, when identify is called with dedup enabled, then address is not updated")
    func testIdentifyWithSameAddress() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

        let traits: [String: Any] = [
            "address": [
                "city": "San Francisco",
                "country": "USA"
            ]
        ]

        let event = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: traits)

        brazeIntegration.identify(payload: event)

        // Reset to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        brazeIntegration.identify(payload: event) // Same event again

        #expect(mockAdapter.changeUserCalls.count == 0) // Same user ID
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No address update due to same values
    }

    // MARK: - Birthday Date Handling Tests

    @Test("Given identify event with same birthday, when identify is called with dedup enabled, then birthday is not updated")
    func testIdentifyWithSameBirthday() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

        let birthday = Date(timeIntervalSince1970: 631152000) // 1990-01-01
        let traits: [String: Any] = ["birthday": birthday]

        let event = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: traits)

        brazeIntegration.identify(payload: event)

        // Reset to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        brazeIntegration.identify(payload: event) // Same birthday again

        #expect(mockAdapter.changeUserCalls.count == 0)
        #expect(mockAdapter.setUserAttributeCalls.count == 0) // No birthday update due to same date
    }

    @Test("Given identify event with different birthday, when identify is called with dedup enabled, then birthday is updated")
    func testIdentifyWithDifferentBirthday() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig) // supportDedup: true

        let firstBirthday = Date(timeIntervalSince1970: 631152000) // 1990-01-01
        let secondBirthday = Date(timeIntervalSince1970: 662688000) // 1991-01-01

        let firstTraits: [String: Any] = ["birthday": firstBirthday]
        let secondTraits: [String: Any] = ["birthday": secondBirthday]

        let firstEvent = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: firstTraits)
        let secondEvent = BrazeTestData.createIdentifyEvent(userId: "user_123", traits: secondTraits)

        brazeIntegration.identify(payload: firstEvent)

        // Reset to track only second call
        mockAdapter.setUserAttributeCalls.removeAll()
        mockAdapter.changeUserCalls.removeAll()

        brazeIntegration.identify(payload: secondEvent)

        #expect(mockAdapter.changeUserCalls.count == 0)
        verifyBirthdayAttribute(mockAdapter, expectedValue: secondBirthday) // Verify birthday was updated
    }

    // MARK: - User ID Change Tests

    @Test("Given identify event with different user ID, when identify is called, then changeUser is called")
    func testIdentifyWithDifferentUserId() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let firstEvent = BrazeTestData.createIdentifyEvent(userId: "user_123")
        let secondEvent = BrazeTestData.createIdentifyEvent(userId: "user_456")

        brazeIntegration.identify(payload: firstEvent)
        brazeIntegration.identify(payload: secondEvent)

        #expect(mockAdapter.changeUserCalls.count == 2)
        #expect(mockAdapter.changeUserCalls[0] == "user_123")
        #expect(mockAdapter.changeUserCalls[1] == "user_456")
    }

    @Test("Given identify event with same user ID, when identify is called, then changeUser is not called on second time")
    func testIdentifyWithSameUserId() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let event = BrazeTestData.createIdentifyEvent(userId: "user_123")

        brazeIntegration.identify(payload: event)

        // Reset to track only second call
        mockAdapter.changeUserCalls.removeAll()

        brazeIntegration.identify(payload: event) // Same user ID

        #expect(mockAdapter.changeUserCalls.count == 0) // No changeUser call for same user ID
    }

    // MARK: - External ID Priority Tests

    @Test("Given identify event with both external ID and user ID, when identify is called, then external ID takes priority")
    func testIdentifyExternalIdPriority() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let externalIds = BrazeTestData.createExternalIds(brazeExternalId: "external_123")
        let identifyEvent = BrazeTestData.createIdentifyEvent(
            userId: "user_456", // This should be ignored
            traits: BrazeTestData.basicUserTraits,
            externalIds: externalIds
        )

        brazeIntegration.identify(payload: identifyEvent)

        #expect(mockAdapter.changeUserCalls.count == 1)
        #expect(mockAdapter.changeUserCalls[0] == "external_123") // External ID used, not user ID
    }

    @Test("Given identify event with external ID change, when identify is called, then changeUser is called with new external ID")
    func testIdentifyWithExternalIdChange() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let firstExternalIds = BrazeTestData.createExternalIds(brazeExternalId: "external_123")
        let secondExternalIds = BrazeTestData.createExternalIds(brazeExternalId: "external_456")

        let firstEvent = BrazeTestData.createIdentifyEvent(externalIds: firstExternalIds)
        let secondEvent = BrazeTestData.createIdentifyEvent(externalIds: secondExternalIds)

        brazeIntegration.identify(payload: firstEvent)
        brazeIntegration.identify(payload: secondEvent)

        #expect(mockAdapter.changeUserCalls.count == 2)
        #expect(mockAdapter.changeUserCalls[0] == "external_123")
        #expect(mockAdapter.changeUserCalls[1] == "external_456")
    }

    // MARK: - Revenue Conversion Tests

    @Test("Given Order Completed event with various price formats, when track is called, then prices are converted correctly")
    func testOrderCompletedWithVariousPriceFormats() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let properties: [String: Any] = [
            "products": [
                [
                    "product_id": "prod1",
                    "price": "99.99" // String price
                ],
                [
                    "product_id": "prod2",
                    "price": NSDecimalNumber(string: "49.50") // NSDecimalNumber price
                ],
                [
                    "product_id": "prod3",
                    "price": 25.75 // Double price
                ]
            ]
        ]

        let trackEvent = BrazeTestData.createTrackEvent(name: "Order Completed", properties: properties)

        brazeIntegration.track(payload: trackEvent)

        #expect(mockAdapter.logPurchaseCalls.count == 3)
        #expect(mockAdapter.logPurchaseCalls[0].price == 99.99)
        #expect(mockAdapter.logPurchaseCalls[1].price == 49.50)
        #expect(mockAdapter.logPurchaseCalls[2].price == 25.75)
    }

    // MARK: - Custom Attribute Array Handling Tests

    @Test("Given identify event with array custom attribute, when identify is called, then array is converted to JSON string")
    func testIdentifyWithArrayCustomAttribute() throws {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
        brazeIntegration.analytics = createMockAnalytics()

        try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)

        let traits: [String: Any] = [
            "interests": ["sports", "music", "travel"],
            "scores": [85, 92, 78]
        ]

        let identifyEvent = BrazeTestData.createIdentifyEvent(traits: traits)

        brazeIntegration.identify(payload: identifyEvent)

        let arrayAttributes = mockAdapter.setCustomAttributeCalls.filter { call in
            call.value is String && (call.key == "interests" || call.key == "scores")
        }

        #expect(arrayAttributes.count == 2) // Both arrays should be converted to JSON strings

        // Verify that the arrays were converted to valid JSON strings
        for attribute in arrayAttributes {
            let jsonString = attribute.value as! String
            #expect(jsonString.hasPrefix("["))
            #expect(jsonString.hasSuffix("]"))
        }
    }

    // MARK: - Log Level Mapping Tests

    @Test("Given different RudderStack log levels, when integration is created, then Braze log levels are mapped correctly")
    func testLogLevelMapping() throws {
        let logLevelMappings: [(LogLevel, Braze.Configuration.Logger.Level)] = [
            (.verbose, .debug),
            (.debug, .debug),
            (.info, .info),
            (.warn, .error),
            (.error, .error),
            (.none, .disabled)
        ]

        for (rudderLevel, expectedBrazeLevel) in logLevelMappings {
            let mockAdapter = MockBrazeAdapter()
            let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)
            brazeIntegration.analytics = createMockAnalytics()
            LoggerAnalytics.logLevel = rudderLevel
            try brazeIntegration.create(destinationConfig: BrazeTestData.validConfig)
            #expect(mockAdapter.setLogLevelCalls.first == expectedBrazeLevel)
        }
    }

    // MARK: - Empty Configuration Tests

    @Test("Given empty configuration dictionary, when create is called, then throws invalidAPIToken error")
    func testCreateWithEmptyConfiguration() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        #expect(throws: BrazeIntegrationError.invalidAPIToken) {
            try brazeIntegration.create(destinationConfig: [:])
        }
    }

    @Test("Given configuration with empty API key, when create is called, then throws invalidAPIToken error")
    func testCreateWithEmptyAPIKey() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        let config: [String: Any] = [
            "appKey": "", // Empty string
            "dataCenter": "US-01"
        ]

        #expect(throws: BrazeIntegrationError.invalidAPIToken) {
            try brazeIntegration.create(destinationConfig: config)
        }
    }

    @Test("Given configuration with empty data center, when create is called, then throws invalidDataCenter error")
    func testCreateWithEmptyDataCenter() {
        let mockAdapter = MockBrazeAdapter()
        let brazeIntegration = createBrazeIntegration(mockAdapter: mockAdapter)

        let config: [String: Any] = [
            "appKey": "test-key",
            "dataCenter": "   " // Whitespace only
        ]

        #expect(throws: BrazeIntegrationError.invalidDataCenter) {
            try brazeIntegration.create(destinationConfig: config)
        }
    }
}

// MARK: - Test Helper Extension
extension BrazeIntegrationTests {
    
    // MARK: - Helper Functions for Attribute Verification
    
    private func verifyEmailAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .email(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyFirstNameAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .firstName(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyLastNameAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .lastName(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyPhoneAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .phoneNumber(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyGenderAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: Braze.User.Gender) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .gender(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyHomeCityAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .homeCity(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyCountryAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: String) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .country(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyCustomAttribute<T: Equatable>(_ mockAdapter: MockBrazeAdapter, key: String, expectedValue: T) {
        let attribute = mockAdapter.setCustomAttributeCalls.first { $0.key == key }
        #expect(attribute?.value as? T == expectedValue)
    }
    
    private func verifyBasicUserAttributes(_ mockAdapter: MockBrazeAdapter) {
        verifyEmailAttribute(mockAdapter, expectedValue: "test@example.com")
        verifyFirstNameAttribute(mockAdapter, expectedValue: "John")
        verifyLastNameAttribute(mockAdapter, expectedValue: "Doe")
    }
    
    private func verifyBirthdayAttribute(_ mockAdapter: MockBrazeAdapter, expectedValue: Date) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .dateOfBirth(let value) = attr, value == expectedValue {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
    
    private func verifyAttributionDataAttribute(_ mockAdapter: MockBrazeAdapter) {
        let attribute = mockAdapter.setUserAttributeCalls.first { attr in
            if case .attributionData = attr {
                return true
            }
            return false
        }
        #expect(attribute != nil)
    }
}
