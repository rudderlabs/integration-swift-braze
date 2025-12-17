//
//  UtilsTests.swift
//  integration-swift-braze
//
//  Tests for utility functions in Utils.swift
//

import Testing
import Foundation
import RudderStackAnalytics
@testable import RudderIntegrationBraze

@Suite(.serialized)
struct UtilsTests {

    // MARK: - Test Data

    /// Complete trait set 1 with all supported fields
    nonisolated(unsafe) static let completeTraits1 = IdentifyTraits(
        userId: "user_123",
        context: Context(
            traits: Traits(
                email: "test@example.com",
                firstName: "John",
                lastName: "Doe",
                gender: "Male",
                phone: "+1234567890",
                address: Address(city: "San Francisco", country: "USA"),
                birthday: Date(timeIntervalSince1970: 631152000) // 1990-01-01
            ),
            externalId: [ExternalId(type: "brazeExternalId", id: "external_456")]
        ),
        customTraits: [
            "customKey1": "customValue1",
            "customKey2": 42,
            "customKey3": true
        ]
    )

    /// Complete trait set 2 with different values
    nonisolated(unsafe) static let completeTraits2 = IdentifyTraits(
        userId: "user_456",
        context: Context(
            traits: Traits(
                email: "jane@example.com",
                firstName: "Jane",
                lastName: "Smith",
                gender: "Female",
                phone: "+9876543210",
                address: Address(city: "New York", country: "USA"),
                birthday: Date(timeIntervalSince1970: 725846400) // 1993-01-01
            ),
            externalId: [ExternalId(type: "brazeExternalId", id: "external_789")]
        ),
        customTraits: [
            "customKey1": "customValue2",
            "customKey2": 100,
            "customKey4": "newValue"
        ]
    )

    // MARK: - parse() Tests

    @Test("given valid dictionary, when parse is called, then returns decoded object")
    func testParseValidDictionary() {
        let config: [String: Any] = [
            "appKey": "test-api-key-123",
            "dataCenter": "US-01",
            "supportDedup": true,
            "connectionMode": "device"
        ]

        let result: RudderBrazeConfig? = parse(config)

        #expect(result != nil)
        #expect(result?.resolvedApiKey == "test-api-key-123")
        #expect(result?.supportDedup == true)
    }

    @Test("given empty dictionary, when parse is called, then returns nil")
    func testParseEmptyDictionary() {
        let emptyConfig: [String: Any] = [:]

        let result: RudderBrazeConfig? = parse(emptyConfig)

        #expect(result == nil)
    }

    @Test("given invalid structure, when parse is called, then returns nil")
    func testParseInvalidStructure() {
        let invalidConfig: [String: Any] = [
            "appKey": 12345, // Wrong type - should be String
            "dataCenter": true // Wrong type - should be String
        ]

        let result: RudderBrazeConfig? = parse(invalidConfig)

        #expect(result == nil)
    }

    // MARK: - getStandardProperties() Tests

    @Test("given valid properties, when getStandardProperties is called, then returns StandardProperties")
    func testGetStandardPropertiesValid() {
        let properties: [String: Any] = [
            "currency": "USD",
            "revenue": 99.99,
            "products": [
                ["product_id": "prod_001", "price": 50.0]
            ]
        ]

        let result = getStandardProperties(properties)

        #expect(result.currency == "USD")
        #expect(result.products.count == 1)
        #expect(result.products[0].productId == "prod_001")
    }

    @Test("given empty properties, when getStandardProperties is called, then returns default StandardProperties")
    func testGetStandardPropertiesEmpty() {
        let emptyProperties: [String: Any] = [:]

        let result = getStandardProperties(emptyProperties)

        #expect(result.currency == "USD") // Default currency
        #expect(result.products.count == 1) // Default contains one empty Product
    }

    // MARK: - filter() Tests

    @Test("given standard and custom properties, when filter is called, then returns only custom")
    func testFilterStandardAndCustomProperties() {
        let properties: [String: Any] = [
            "revenue": 99.99,
            "currency": "USD",
            "customKey1": "customValue1",
            "customKey2": 42
        ]

        let rootKeys = ["revenue", "currency"]

        let result = filter(properties: properties, rootKeys: rootKeys)

        #expect(result.count == 2)
        #expect(result["customKey1"] as? String == "customValue1")
        #expect(result["customKey2"] as? Int == 42)
        #expect(result["revenue"] == nil)
        #expect(result["currency"] == nil)
    }

    @Test("given products with custom properties, when filter is called, then extracts from products")
    func testFilterProductsWithCustomProperties() {
        let properties: [String: Any] = [
            "products": [
                [
                    "product_id": "prod_001",
                    "price": 50.0,
                    "customProductKey": "customProductValue"
                ],
                [
                    "product_id": "prod_002",
                    "price": 30.0,
                    "anotherCustomKey": "anotherCustomValue"
                ]
            ]
        ]

        let productKeys = ["product_id", "price", "quantity"]

        let result = filter(properties: properties, rootKeys: [], productKeys: productKeys)

        // Note: If multiple products have the same custom key, only the last value is kept
        #expect(result["customProductKey"] as? String == "customProductValue")
        #expect(result["anotherCustomKey"] as? String == "anotherCustomValue")
        #expect(result["product_id"] == nil)
        #expect(result["price"] == nil)
    }

    @Test("given no products, when filter is called, then returns filtered root only")
    func testFilterNoProducts() {
        let properties: [String: Any] = [
            "revenue": 99.99,
            "customKey": "customValue"
        ]

        let rootKeys = ["revenue"]

        let result = filter(properties: properties, rootKeys: rootKeys, productKeys: ["price"])

        #expect(result.count == 1)
        #expect(result["customKey"] as? String == "customValue")
    }

    @Test("given only standard properties, when filter is called, then returns empty")
    func testFilterOnlyStandardProperties() {
        let properties: [String: Any] = [
            "revenue": 99.99,
            "currency": "USD"
        ]

        let rootKeys = ["revenue", "currency"]

        let result = filter(properties: properties, rootKeys: rootKeys)

        #expect(result.isEmpty)
    }

    // MARK: - getExternalIdOrUserId() Tests

    @Test("given both externalId and userId, when called, then returns externalId")
    func testGetExternalIdPriority() {
        let traits = IdentifyTraits(
            userId: "user_123",
            context: Context(
                traits: Traits(),
                externalId: [
                    ExternalId(type: "brazeExternalId", id: "external_456")
                ]
            ),
            customTraits: [:]
        )

        let result = getExternalIdOrUserId(from: traits)

        #expect(result == "external_456")
    }

    @Test("given only userId, when called, then returns userId")
    func testGetUserIdWhenNoExternalId() {
        let traits = IdentifyTraits(
            userId: "user_123",
            context: Context(
                traits: Traits(),
                externalId: nil
            ),
            customTraits: [:]
        )

        let result = getExternalIdOrUserId(from: traits)

        #expect(result == "user_123")
    }

    @Test("given empty externalId array, when called, then returns userId")
    func testGetUserIdWhenEmptyExternalId() {
        let traits = IdentifyTraits(
            userId: "user_123",
            context: Context(
                traits: Traits(),
                externalId: []
            ),
            customTraits: [:]
        )

        let result = getExternalIdOrUserId(from: traits)

        #expect(result == "user_123")
    }

    // MARK: - toIdentifyTraits() Tests

    @Test("given IdentifyEvent with all supported fields including custom traits, when converted, then returns complete IdentifyTraits")
    func testToIdentifyTraitsComplete() {
        var event = IdentifyEvent()
        event.userId = "user_123"

        let contextDict: [String: Any] = [
            "traits": [
                "email": "test@example.com",
                "firstName": "John",
                "lastName": "Doe",
                "gender": "Male",
                "phone": "+1234567890",
                "address": [
                    "city": "San Francisco",
                    "country": "USA"
                ],
                "birthday": "1990-05-15T00:00:00.000Z",
                "customKey1": "customValue1",
                "customKey2": 42,
                "customKey3": true
            ],
            "externalId": [
                ["type": "brazeExternalId", "id": "external_456"]
            ]
        ]
        event.context = contextDict.mapValues { AnyCodable($0) }

        let result = toIdentifyTraits(from: event)

        // Verify userId
        #expect(result.userId == "user_123")

        // Verify standard traits
        #expect(result.context.traits.email == "test@example.com")
        #expect(result.context.traits.firstName == "John")
        #expect(result.context.traits.lastName == "Doe")
        #expect(result.context.traits.gender == "Male")
        #expect(result.context.traits.phone == "+1234567890")

        // Verify address
        #expect(result.context.traits.address != nil)
        #expect(result.context.traits.address?.city == "San Francisco")
        #expect(result.context.traits.address?.country == "USA")

        // Verify birthday
        #expect(result.context.traits.birthday != nil)

        // Verify brazeExternalId
        #expect(result.context.brazeExternalId == "external_456")

        // Verify custom traits are extracted and standard keys are filtered out
        #expect(result.customTraits.count == 3)
        #expect(result.customTraits["customKey1"] as? String == "customValue1")
        #expect(result.customTraits["customKey2"] as? Int == 42)
        #expect(result.customTraits["customKey3"] as? Bool == true)

        // Verify standard keys are filtered out from custom traits
        #expect(result.customTraits["email"] == nil)
        #expect(result.customTraits["firstName"] == nil)
        #expect(result.customTraits["lastName"] == nil)
        #expect(result.customTraits["gender"] == nil)
        #expect(result.customTraits["phone"] == nil)
        #expect(result.customTraits["address"] == nil)
        #expect(result.customTraits["birthday"] == nil)
    }

    // MARK: - deDupe() Tests

    @Test("given nil previousTraits, when deDupe is called, then returns all current traits")
    func testDeDupeNoPreviousTraits() {
        let result = deDupe(currentTraits: UtilsTests.completeTraits1, previousTraits: nil)

        #expect(result.userId == "user_123")
        #expect(result.context.traits.email == "test@example.com")
        #expect(result.context.traits.firstName == "John")
        #expect(result.context.traits.lastName == "Doe")
        #expect(result.context.traits.gender == "Male")
        #expect(result.context.traits.phone == "+1234567890")
        #expect(result.context.traits.address?.city == "San Francisco")
        #expect(result.context.traits.address?.country == "USA")
        #expect(result.context.traits.birthday != nil)
        #expect(result.customTraits.count == 3)
    }

    @Test("given identical traits, when deDupe is called, then returns nil for all")
    func testDeDupeIdenticalTraits() {
        let result = deDupe(currentTraits: UtilsTests.completeTraits1, previousTraits: UtilsTests.completeTraits1)

        #expect(result.userId == nil)
        #expect(result.context.traits.email == nil)
        #expect(result.context.traits.firstName == nil)
        #expect(result.context.traits.lastName == nil)
        #expect(result.context.traits.gender == nil)
        #expect(result.context.traits.phone == nil)
        #expect(result.context.traits.address == nil)
        #expect(result.context.traits.birthday == nil)
        #expect(result.customTraits.isEmpty)
    }

    @Test("given different traits, when deDupe is called, then returns only changed")
    func testDeDupeDifferentTraits() {
        let result = deDupe(currentTraits: UtilsTests.completeTraits2, previousTraits: UtilsTests.completeTraits1)

        // Changed fields
        #expect(result.userId == "user_456")
        #expect(result.context.traits.email == "jane@example.com")
        #expect(result.context.traits.firstName == "Jane")
        #expect(result.context.traits.lastName == "Smith")
        #expect(result.context.traits.gender == "Female")
        #expect(result.context.traits.phone == "+9876543210")
        #expect(result.context.traits.address?.city == "New York")
        #expect(result.context.traits.address?.country == "USA")
        #expect(result.context.traits.birthday != nil)
        #expect(result.customTraits.count == 3)
    }

    // MARK: - Date Conversion Tests

    @Test("given valid ISO8601 date string with fractional seconds, when parsed, then returns Date")
    func testDateConversionValidISO8601() {
        let dateString = "2024-01-15T10:30:45.123Z"

        let result = DateFormatters.iso8601WithFractionalSeconds.date(from: dateString)

        #expect(result != nil)
    }

    @Test("given invalid date string, when parsed, then returns nil")
    func testDateConversionInvalidString() {
        let invalidDateString = "not-a-date"

        let result = DateFormatters.iso8601WithFractionalSeconds.date(from: invalidDateString)

        #expect(result == nil)
    }
}
