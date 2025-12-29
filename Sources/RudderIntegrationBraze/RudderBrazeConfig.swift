//
//  RudderBrazeConfig.swift
//  RudderIntegrationBraze
//
//  Configuration models for Braze Integration
//

import Foundation
import RudderStackAnalytics

private let brazeExternalIdKey = "brazeExternalId"

/**
 * Structure representing the configuration for Braze Integration.
 *
 * - Parameters:
 *   - apiKey: The API key for Braze (serialized as "appKey" for backward compatibility).
 *             Used as fallback when platform-specific keys are not configured.
 *   - iOSApiKey: The iOS-specific API key for Braze. Takes precedence when usePlatformSpecificApiKeys is true.
 *   - usePlatformSpecificApiKeys: Flag to enable platform-specific API key resolution.
 *   - customEndpoint: The custom endpoint for the data center. Must not be empty or blank.
 *   - supportDedup: Flag indicating whether deduplication is supported.
 *   - connectionMode: The mode of connection, either hybrid or device.
 *
 * - Throws: DecodingError if resolved apiKey or customEndpoint is invalid.
 */
struct RudderBrazeConfig: Codable {

    let apiKey: String
    let iOSApiKey: String?
    let usePlatformSpecificApiKeys: Bool
    let customEndpoint: String
    let supportDedup: Bool
    let connectionMode: ConnectionMode

    enum CodingKeys: String, CodingKey {
        // We cannot change the legacy "appKey" field to "apiKey".
        case apiKey = "appKey"
        case iOSApiKey
        case usePlatformSpecificApiKeys
        case customEndpoint = "dataCenter"
        case supportDedup
        case connectionMode
    }

    /**
     * Resolves the API key to use based on platform-specific configuration.
     * Prefers iOSApiKey when usePlatformSpecificApiKeys is enabled and iOSApiKey is not blank.
     * Falls back to the legacy apiKey otherwise.
     */
    var resolvedApiKey: String {
        if usePlatformSpecificApiKeys {
            if let iosKey = iOSApiKey, !iosKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return iosKey
            } else {
                LoggerAnalytics.error("BrazeIntegration: Configured to use platform-specific API keys but iOS API key is not valid. Falling back to the default API key.")
                return apiKey
            }
        } else {
            return apiKey
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        apiKey = try container.decode(String.self, forKey: .apiKey)
        iOSApiKey = try container.decodeIfPresent(String.self, forKey: .iOSApiKey)
        usePlatformSpecificApiKeys = try container.decodeIfPresent(Bool.self, forKey: .usePlatformSpecificApiKeys) ?? false
        supportDedup = try container.decode(Bool.self, forKey: .supportDedup)
        connectionMode = try container.decode(ConnectionMode.self, forKey: .connectionMode)

        // Custom decoding for customEndpoint with data center mapping
        let dataCenterString = try container.decode(String.self, forKey: .customEndpoint)
        customEndpoint = try CustomEndpointDecoder.decode(dataCenterString)

        // Validation
        guard !resolvedApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .apiKey,
                in: container,
                debugDescription: "Invalid API key. Aborting Braze initialization."
            )
        }

        guard !customEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .customEndpoint,
                in: container,
                debugDescription: "dataCenter cannot be empty or blank"
            )
        }
    }

    func isHybridMode() -> Bool {
        switch connectionMode {
        case .hybrid:
            LoggerAnalytics.verbose("BrazeIntegration: As connection mode is set to hybrid, dropping event request.")
            return true
        case .device:
            return false
        }
    }
}

/**
 * Enum representing the connection modes for Braze Integration.
 */
enum ConnectionMode: String, Codable {

    /**
     * Represents the hybrid connection mode.
     */
    case hybrid = "hybrid"

    /**
     * Represents the device connection mode.
     */
    case device = "device"
}

/**
 * Custom decoder for mapping custom endpoint identifiers to their corresponding URLs.
 */
private struct CustomEndpointDecoder {

    /**
     * Mapping of custom endpoint identifiers to their corresponding URLs.
     */
    private static let customEndpointMapping: [String: String] = [
        "US-01": "sdk.iad-01.braze.com",
        "US-02": "sdk.iad-02.braze.com",
        "US-03": "sdk.iad-03.braze.com",
        "US-04": "sdk.iad-04.braze.com",
        "US-05": "sdk.iad-05.braze.com",
        "US-06": "sdk.iad-06.braze.com",
        "US-07": "sdk.iad-07.braze.com",
        "US-08": "sdk.iad-08.braze.com",
        "EU-01": "sdk.fra-01.braze.eu",
        "EU-02": "sdk.fra-02.braze.eu",
        "AU-01": "sdk.au-01.braze.com"
    ]

    static func decode(_ dataCenter: String) throws -> String {
        let uppercaseDataCenter = dataCenter.uppercased()
        guard let endpoint = customEndpointMapping[uppercaseDataCenter] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Unsupported data center: \(dataCenter)"
                )
            )
        }
        return endpoint
    }
}

/**
 * Structure representing the attribution details of an install event.
 *
 * - Parameters:
 *   - campaign: The campaign details associated with the install. Can be nil if user does not provide any.
 */
struct InstallAttributed: Codable {
    let campaign: Campaign?
}

/**
 * Structure representing campaign details for install attribution.
 *
 * - Parameters:
 *   - source: The source of the campaign.
 *   - name: The name of the campaign.
 *   - adGroup: The ad group name of the campaign.
 *   - adCreative: The ad creative name/ID used in the campaign.
 */
struct Campaign: Codable {
    let source: String?
    let name: String?
    let adGroup: String?
    let adCreative: String?

    enum CodingKeys: String, CodingKey {
        case source
        case name
        case adGroup = "ad_group"
        case adCreative = "ad_creative"
    }
}

/**
 * Structure representing standard properties for a transaction.
 *
 * - Parameters:
 *   - currency: The currency code used for the transaction. Defaults to "USD".
 *   - products: List of products included in the transaction. Defaults to empty array.
 */
struct StandardProperties: Codable {
    let currency: String
    let products: [Product]

    init(currency: String = "USD", products: [Product] = [Product()]) {
        self.currency = currency
        self.products = products
    }

    static func getKeysAsList() -> [String] {
        return ["currency", "products"]
    }
}

/**
 * Structure representing a product in a transaction.
 *
 * - Parameters:
 *   - productId: The unique identifier for the product.
 *   - price: The price of the product as a Double.
 */
struct Product: Codable {
    let productId: String?
    let price: Double
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case quantity
    }

    init(productId: String? = nil, price: Double = 0.0, quantity: Int = 1) {
        self.productId = productId
        self.price = price
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        productId = try container.decodeIfPresent(String.self, forKey: .productId)

        // Decode price as Decimal and convert to Double
        if let decimalPrice = try container.decodeIfPresent(Decimal.self, forKey: .price) {
            price = NSDecimalNumber(decimal: decimalPrice).doubleValue
        } else {
            price = 0.0
        }

        // Decode quantity with default of 1
        // Handle both Int and String types (like Android does)
        if let intQuantity = try container.decodeIfPresent(Int.self, forKey: .quantity) {
            quantity = intQuantity
        } else if let stringQuantity = try container.decodeIfPresent(String.self, forKey: .quantity),
                  let parsedQuantity = Int(stringQuantity) {
            quantity = parsedQuantity
        } else {
            quantity = 1
        }
    }

    static func getKeysAsList() -> [String] {
        return ["product_id", "price", "quantity"]
    }

    func isNotEmpty() -> Bool {
        return productId != nil || price != 0.0
    }
}

/**
 * Structure representing the traits of a user for identification.
 *
 * - Parameters:
 *   - userId: The unique identifier for the user.
 *   - context: The context associated with the user.
 *   - customTraits: The custom traits associated with the user.
 */
struct IdentifyTraits {
    let userId: String?
    let context: Context
    let customTraits: [String: Any]

    init(userId: String? = nil, context: Context = Context(), customTraits: [String: Any] = [:]) {
        self.userId = userId
        self.context = context
        self.customTraits = customTraits
    }
}

/**
 * Structure representing the context associated with a user.
 *
 * - Parameters:
 *   - traits: The traits associated with the user.
 *   - externalId: The external identifiers associated with the user.
 */
struct Context: Codable {
    let traits: Traits
    let externalId: [ExternalId]?

    init(traits: Traits = Traits(), externalId: [ExternalId]? = nil) {
        self.traits = traits
        self.externalId = externalId
    }

    /**
     * Returns the Braze external identifier for the user.
     */
    var brazeExternalId: String? {
        return externalId?.first(where: { $0.type == brazeExternalIdKey })?.id
    }
}

/**
 * Structure representing external identifiers.
 *
 * - Parameters:
 *   - type: The type of external identifier.
 *   - id: The identifier value.
 */
struct ExternalId: Codable, Equatable {
    let type: String
    let id: String
}

/**
 * Structure representing the traits associated with a user.
 *
 * - Parameters:
 *   - email: The email address of the user.
 *   - firstName: The first name of the user.
 *   - lastName: The last name of the user.
 *   - gender: The gender of the user.
 *   - phone: The phone number of the user.
 *   - address: The address of the user.
 *   - birthday: The birthday of the user.
 */
struct Traits: Codable {
    let email: String?
    let firstName: String?
    let lastName: String?
    let gender: String?
    let phone: String?
    let address: Address?
    let birthday: Date?

    init(
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        gender: String? = nil,
        phone: String? = nil,
        address: Address? = nil,
        birthday: Date? = nil
    ) {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.phone = phone
        self.address = address
        self.birthday = birthday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        email = try container.decodeIfPresent(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(Address.self, forKey: .address)

        // Parse birthday using ISO8601 format
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
            .flatMap { DateFormatters.iso8601WithFractionalSeconds.date(from: $0) }
    }

    static func getKeysAsList() -> [String] {
        return [
            "email",
            "firstName",
            "lastName",
            "gender",
            "phone",
            "address",
            "birthday"
        ]
    }
}

/**
 * Structure representing the address of a user.
 *
 * - Parameters:
 *   - city: The city of the user.
 *   - country: The country of the user.
 */
struct Address: Codable, Equatable {
    let city: String?
    let country: String?

    init(city: String? = nil, country: String? = nil) {
        self.city = city
        self.country = country
    }
}
